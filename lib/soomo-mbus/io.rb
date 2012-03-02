module Mbus

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::Io, is used to perform Io with rabbitmq. 
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

  class Io 
    
    @@options, @@exchanges, @@queues, @@bunny = {}, {}, {}, nil
    
    def self.initialize(app_name=nil, opts={})
      @@options  = opts
      @@app_name = app_name
      @@app_name = ENV['MBUS_APP'] if @@app_name.nil? # See Procfile or Rails initializer for MBUS_APP.
      if (@@app_name.nil?)
        puts "#{classname}.initialize ERROR - unable to determine MBUS_APP name" unless silent?
        return
      end
      puts "#{log_prefix}.initialize starting" unless silent?
      Mbus::Config.initialize(@@app_name, options)
      started = (start_bunny?) ? start : false
      puts "#{log_prefix}.initialize - completed, bunny started: #{started}" unless silent?
    end
    
    def self.start
      begin
        if @@bunny
          puts "#{log_prefix}.start; stopping the previous @@bunny" unless silent?
          @@bunny.stop 
        end
      rescue Exception => e1
        puts "#{log_prefix}.start Exception - #{e1.message} #{e1.inspect}" unless silent?
        false
      end
      
      begin
        url = Mbus::Config.rabbitmq_url
        puts "#{log_prefix}.starting - rabbitmq_url: #{url}" unless silent?
        @@bunny = Bunny.new(url)
        @@bunny.start
        if Mbus::Config.initialize_exchanges?
          Mbus::Config::exchange_entries_for_app(@@app_name).each { | exch_entry |
            initialize_exchange(exch_entry)
          }
        end
        puts "#{log_prefix}.start - completed" unless silent?
        true
      rescue Exception => excp
        puts "#{log_prefix}.start Exception - #{excp.message} #{excp.inspect}" unless silent?
        false
      end
    end

    def self.options
      @@options
    end
    
    def self.exchanges
      @@exchanges
    end
    
    def self.queues
      @@queues
    end
    
    def self.classname
      'Mbus::Io'
    end

    def self.app_name
      @@app_name
    end
    
    def self.log_prefix
      "#{app_name} #{classname}"
    end
    
    def self.verbose?
      @@options[:verbose] && @@options[:verbose] == true
    end
    
    def self.silent?
      @@options[:silent] && @@options[:silent] == true 
    end
    
    def self.start_bunny? 
      (@@options[:start_bunny].to_s == 'false') ? false : true
    end 
    
    def self.shutdown
      puts "#{log_prefix}.shutdown starting..." unless silent?
      @@bunny.stop if @@bunny
      puts "#{log_prefix}.shutdown completed." unless silent?
    end
    
    def self.initialize_exchange(exch_entry)
      begin
        ew = Mbus::ExchangeWrapper.new(exch_entry)
        e  = @@bunny.exchange(ew.name, {:type => ew.type_symbol})
        if e
          ew.exchange = e
          @@exchanges[ew.name] = ew
          puts "#{log_prefix}.initialize_exchange - created exchange '#{ew.name}'" unless silent?
          if Mbus::Config::is_consumer?(app_name)
            Mbus::Config::queues_for_app(app_name).each { | queue_entry |
              qw = QueueWrapper.new(queue_entry) # wraps a config entry and the actual queue
              if qw.is_exchange?(ew.name)
                q = @@bunny.queue(qw.name, {:durable => qw.durable?})
                q.bind(ew.name, :key => qw.key)
                qw.queue = q
                @@queues[qw.fullname] = qw
                puts "#{log_prefix}.initialize_exchange - bound '#{qw.fullname}' to '#{qw.key}'" unless silent?
              end 
            }
          else
            # producers don't need to define queues
          end
        else
          puts "#{log_prefix}.initialize_exchange - exchange NOT created '#{ew.name}'" unless silent? 
        end 
      rescue Exception => excp
        puts "#{log_prefix}.initialize_exchange Exception - #{excp.message} #{excp.inspect}" unless silent?
      end 
    end
    
    def self.fullname(exch_name, queue_name)
      "#{exch_name}|#{queue_name}"
    end
    
    def self.delete_exchange(exch_name, opts={})
      ew = @@exchanges[exch_name]
      (ew.nil?) ? nil : ew.exchange.delete(opts)
    end 

    def self.send_message(exch_name, json_str_msg, routing_key)
      result = nil
      begin
        ew = @@exchanges[exch_name.to_s]
        if ew && json_str_msg && routing_key
          ew.exchange.publish(json_str_msg,
            {:key        => routing_key,
             :persistent => ew.persistent?, 
             :mandatory  => ew.mandatory?,
             :immediate  => ew.immediate?})
          puts "#{log_prefix}.send_message exch: '#{ew.name}' key: '#{routing_key}' msg: #{json_str_msg}" if verbose?
          result = json_str_msg
        else
          puts "#{log_prefix}.send_message - invalid value(s) for exch #{exch_name}" unless silent?
        end
      rescue Exception => excp
        puts "#{log_prefix}.send_message Exception - #{excp.message} #{excp.inspect}"
      end 
      result
    end

    def self.status
      hash = {}
      begin
        @@queues.keys.sort.each { | fullname |
          qw = @@queues[fullname]
          hash[fullname] = qw.queue.status if qw
        }  
      rescue Exception => excp
        puts "#{log_prefix}.status Exception - #{excp.message} #{excp.inspect}"
      end
      hash
    end
    
    def self.ack_queue(exch_name, queue_name)
      begin
        qw = @@queues[fullname(exch_name, queue_name)]
        if qw && qw.queue && qw.ack?
          qw.queue.ack
        end
      rescue Exception => excp
        puts "#{log_prefix}.ack_queue Exception on exch: #{exch_name} queue: #{queue_name} - #{excp.message} #{excp.inspect}"
      end
    end 

    def self.read_message(exch_name, queue_name)
      begin
        qw = @@queues[fullname(exch_name, queue_name)]
        return qw.queue.pop(:ack => qw.ack?, :nowait => qw.nowait?)[:payload] if qw
      rescue Exception => excp
        puts "#{log_prefix}.read_message Exception on exch: #{exch_name} queue: #{queue_name} - #{excp.message} #{excp.inspect}"
      end
      nil
    end
    
  end
  
end 
