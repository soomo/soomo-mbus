module Mbus 

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::Config, is be used to obtain configuration
  # values used in this gem, such as for rabbitmq.  The configuration is
  # centrally stored in JSON format, at the Redis location(s) indicated by
  # the MBUS_HOME environment variable.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

  class Config

    @@options, @@app_name, @@config_locations, @@config_obj, @@routing_keys = nil, nil, nil, nil, nil

    def self.initialize(app_name, opts={})
      reset 
      @@options  = opts 
      @@app_name = app_name
      @@app_name = ENV['MBUS_APP'] if @@app_name.nil? 
      puts "#{log_prefix}.initialize starting..." unless silent?
      @@config_locations = (ENV['MBUS_HOME']) ? ENV['MBUS_HOME'].split('^') : []
      puts "#{log_prefix}.initialize config_locations: #{@@config_locations}" unless silent? 
      @@config_obj = read_parse_config
      @@routing_keys = init_routing_keys
      puts "#{log_prefix}.initialize completed" unless silent?  
    end
    
    def self.reset
      @@options = {}
      @@app_name = ''
      @@config_locations = []
      @@config_obj = nil
      @@routing_keys = {}
    end

    def self.exchange(exch_name)
      return nil if exch_name.nil? 
      config_obj['exchanges'].each { | entry |
        return entry if exch_name == entry['name']
      }
      nil
    end
    
    def self.exchange_entries_for_app(app_name)
      return [] if app_name.nil? || config_obj.nil?
      if app_name == 'all'
        return config_obj['exchanges']
      end
      if is_consumer?(app_name)
        exchange_entries_for_consumer_app(app_name)
      else
        exchange_entries_for_producer_app(app_name)
      end
    end
    
    def self.queues_for_app(app_name)
      entry_list = []
      return entry_list if app_name.nil? || config_obj.nil?
      return config_obj['queues'] if app_name == 'all'
      if is_consumer?(app_name)
        consumer_entry = consumer_process_entry_for(app_name)
        if consumer_entry
          consumer_entry['queues'].each { | fullname |
            config_obj['queues'].each { | entry |
              fn = "#{entry['exch']}|#{entry['name']}"
              entry_list << entry if fn == fullname
            }
          }
        end
      else
        # producers don't need to define queues
      end
      entry_list
    end
    
    def self.default_exchange_type
      'topic'
    end
    
    def self.initialize_exchanges?
      return true if @@options[:action].to_s == 'status'
      (@@options[:initialize_exchanges].to_s == 'false') ? false : true
    end 
    
    # Invoked by a rake task
    
    def self.set_config(loc, json_str)
      begin
        return false if loc.nil? || json_str.nil?
        
        # Last line of defense; don't let an invalid JSON String be stored in Redis.
        json_obj = JSON.parse(json_str)
        return false if json_obj.nil? || json_obj.size < 5
        
        tokens = loc.split('#')
        redis_url, redis_key = tokens[0], tokens[1]
        uri = URI.parse(redis_url)
        redis = Redis.new(:host => uri.host,
                          :port => uri.port,
                          :password => uri.password)
        redis.set(redis_key, json_str)
        saved_json = redis.get(redis_key)
        (saved_json.to_s.size == json_str.size) ? true : false
      rescue Exception => e
        puts "#{classname}.set_config Exception - #{e.message} #{e.inspect}" unless silent?
        false
      end 
    end 
    
    def self.classname
      'Mbus::Config'
    end
    
    def self.config_obj
      @@config_obj
    end
    
    def self.app_name
      @@app_name
    end
    
    def self.routing_keys
      @@routing_keys
    end
    
    def self.log_prefix
      "#{app_name} #{classname}"
    end 
    
    def self.config_locations
      @@config_locations
    end
    
    def self.rabbitmq_url
      return @@options[:rabbitmq_url] if @@options[:rabbitmq_url]
      ENV['RABBITMQ_URL'] ||= 'amqp://localhost'
    end
    
    def self.is_consumer?(app_name)
      return false if app_name.nil?
      return true  if app_name == 'all'
      if app_name.include?('consumer')
        config_obj['consumer_processes'].each { | entry |
          return true if app_name == entry['name']
        } 
      end
      false
    end

    def self.routing_lookup_key(obj, action, producer_app=nil)
      producer_app = app_name if producer_app.nil?
      "#{producer_app}|#{obj.class.name}|#{action}".downcase
    end
    
    def self.lookup_routing_key(obj, action, producer_app=nil)
      producer_app = app_name if producer_app.nil?
      routing_keys["#{producer_app}|#{obj.class.name}|#{action}".downcase]
    end
    
    def self.valid_config_json?(json_obj=nil, verbose=true)
      validator = Mbus::ConfigValidator.new(json_obj)
      if validator.valid?
        true
      else
        validator.errors.each { | err | 
          puts "#{classname}.valid_config_json? error - #{err}" unless silent?
        }
        false
      end
    end
    
    def self.verbose?
      @@options[:verbose] && @@options[:verbose] == true 
    end

    def self.silent?
      @@options[:silent] && @@options[:silent] == true
    end
    
    private
    
    def self.init_routing_keys
      hash = {}
      if config_obj.nil? || config_obj['business_functions'].nil?
        puts "#{log_prefix}.init_routing_keys Error - config_obj is invalid" unless silent?  
      else
        config_obj['business_functions'].each { | entry |
          app, obj, act = entry['app'], entry['object'], entry['action']
          hash["#{app}|#{obj}|#{act}".downcase] = entry
        }
        puts "#{log_prefix}.init_routing_keys created; size is #{hash.size}" unless silent? 
      end
      hash
    end

    def self.read_parse_config
      @@config_locations.each_with_index { | loc, idx |
        begin
          tokens = loc.split('#')
          url, key = tokens[0], tokens[1]
          uri = URI.parse(url)
          redis = Redis.new(:host => uri.host,
                            :port => uri.port,
                            :password => uri.password)
          if redis
            json_str = redis.get(key)
            if json_str
              json_obj = JSON.parse(json_str)
              if json_obj
                if valid_config_json?(json_obj)
                  puts "#{log_prefix}.read_parse_config - using the valid JSON from location #{loc}" unless silent? 
                  return json_obj
                else
                  puts "#{log_prefix}.read_parse_config - JSON at location #{loc} is invalid" unless silent?
                end
              else
                puts "#{log_prefix}.read_parse_config - value of redis key #{key} is unparsable at #{url}" unless silent?
              end
            else
              puts "#{log_prefix}.read_parse_config - value of redis key #{key} is nil at #{url}" unless silent?
            end
          else
            puts "#{log_prefix}.read_parse_config - unable to connect to redis at #{url}" unless silent?
          end
        rescue Exception => e
          puts "#{log_prefix}.read_parse_config Exception on location index #{idx} - #{e.message} #{e.inspect}" unless silent?
        end
      }
      nil
    end

    def self.exchange_entries_for_producer_app(app_name)
      exch_names, exch_entries = [], []
      config_obj['business_functions'].each { | entry |
        app, exch = entry['app'], entry['exch']
        exch_names << exch if app_name == app
      }
      exch_names.uniq.sort.each { | exch_name |
        config_obj['exchanges'].each { | entry |
          exch_entries << entry if exch_name == entry['name']
        } 
      }
      exch_entries
    end
    
    def self.exchange_entries_for_consumer_app(app_name)
      exch_names, exch_entries = [], []
      consumer_entry = consumer_process_entry_for(app_name)
      return exch_entries if consumer_entry.nil?
      consumer_entry['queues'].each { | fullname |
        tokens = fullname.split('|')
        exch_names << tokens[0] if tokens.size == 2
      }
      exch_names.uniq.sort.each { | exch_name |
        config_obj['exchanges'].each { | entry |
          exch_entries << entry if exch_name == entry['name']
        } 
      }
      exch_entries 
    end 
    
    def self.consumer_process_entry_for(app_name)
      return nil if app_name.nil?
      config_obj['consumer_processes'].each { | entry |
        return entry if app_name == entry["name"]
      }
      nil
    end

  end
  
end