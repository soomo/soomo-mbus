namespace :mbus do

  namespace :config do
  
    desc "Create the configuration JSON"
    task :create => :environment do
      opts = {}
      opts[:version] = ENV['v']
      opts[:default_exchange] = 'soomo'
      @json_str = Mbus::ConfigBuilder.new(opts).build
      puts "========== Beginning of Config JSON =========="
      puts @json_str
      puts "========== End of Config JSON =========="
    
      json_obj = JSON.parse(@json_str)
      validator = Mbus::ConfigValidator.new(json_obj)
      @valid = validator.valid?
      puts "JSON Config validation successful?: #{@valid}"
      validator.errors.each { | msg | puts "ERROR: #{msg}" }
      validator.warnings.each { | msg | puts "warning: #{msg}" }
    end
  
    desc "Create then deploy the configuration JSON, loc="
    task :deploy => :create do
      loc = ENV['loc']
      loc = ENV['MBUS_HOME'] if loc.nil?
      loc = 'redis://localhost:6379#MBUS_CONFIG' if loc.nil?
      if @valid 
        if @json_str && @json_str.size > 0
          result = Mbus::Config.set_config(loc, @json_str)
          puts "Mbus::Config.set_config successful?: #{result} location: #{loc}"
        else
          puts "error: json_str is empty; didn't save it to Redis"
        end
      else
        puts "error: the json is invalid; didn't save it to Redis"
      end  
    end
  
    desc "Display the deployed configuration JSON"
    task :display_deployed => :environment do
      loc = ENV['loc']
      loc = ENV['MBUS_HOME'] if loc.nil?
      loc = 'redis://localhost:6379#MBUS_CONFIG' if loc.nil?
      if loc.include?('^')
        tokens = loc.split('^')
        loc = tokens[0]
      end
      tokens = loc.split('#')
      redis_url, redis_key = tokens[0], tokens[1]
      begin
        uri = URI.parse(redis_url) 
        redis = Redis.new(:host => uri.host,
                          :port => uri.port,
                          :password => uri.password)
        json_str = redis.get(redis_key)
        
        puts "========== Beginning of Config JSON at location #{loc} =========="
        if json_str.nil?
          puts "nil"
        else
          puts json_str
        end
        puts "========== End of Config JSON at location #{loc} =========="

        json_obj = JSON.parse(json_str)
        validator = Mbus::ConfigValidator.new(json_obj)
        valid = validator.valid?
        puts "JSON Config validation successful?: #{valid}"
        validator.errors.each { | msg | puts "ERROR: #{msg}" }
        validator.warnings.each { | msg | puts "warning: #{msg}" } 
      rescue Exception => e
        puts "Exception - #{e.message} #{e.inspect}"
      end
    end
    
    desc "Setup the exchanges and queues per the centralized config."
    task :setup => :environment do
      app = ENV['app'] ||= 'all'
      ENV['MBUS_APP'] = app 
      opts = {:verbose => true, :silent => false}
      Mbus::Io.initialize(app, opts)
      Mbus::Io.shutdown
    end
  
  end
  
  desc "Display the status of the Mbus"
  task :status => :environment do
    app = ENV['app'] ||= 'all'
    ENV['MBUS_APP'] = app
    opts = {:verbose => true, :silent => false}  
    Mbus::Io.initialize(app, opts)  
    hash = Mbus::Io.status
    hash.keys.sort.each { | fname | 
      puts "exch/queue #{fname} = #{hash[fname]}"
    }
    Mbus::Io.shutdown
  end
  
  desc "Send message(s), e= k= n=" 
  task :send_messages => :environment do
    app    = ENV['app'] ||= 'core' 
    ename  = ENV['e']   ||= 'logs'
    count  = ENV['n']   ||= '10'
    key    = ENV['k']   ||= 'logs.app-core.object-hash.action-logmessage'
    actual = 0
    puts "command-line params:"
    puts "  sending app (app=): #{app}"
    puts "  to exchange (e=):   #{ename}"
    puts "  routing key (k=):   #{key}"
    puts "  message count (n=): #{count}"
    
    Mbus::Io.initialize(app, init_options)
    count.to_i.times do | i |
      actual = actual + 1
      msg  = create_message(actual, body="msg sent to key #{unwild_key(key)}")
      Mbus::Io.send_message(ename, msg.to_json, unwild_key(key))
    end
    Mbus::Io.shutdown
  end 
  
  desc "Read messages; a= e= q= n= "
  task :read_messages => :environment do
    app   = ENV['app'] ||= 'logging-consumer' 
    ename = ENV['e']   ||= 'logs' 
    qname = ENV['q']   ||= 'messages'
    count = ENV['n']   ||= '10'
    puts "command-line params:"
    puts "  consumer app (app=): #{app}"
    puts "  from exchange (e=):  #{ename}"
    puts "  queue (q=):          #{qname}"  
    puts "  message count (n=):  #{count}"
    Mbus::Io.initialize(app, init_options)
    read_loop(ename, qname, count)
    Mbus::Io.shutdown
  end
  
  desc "Send messages to all exchanges and keys, n="
  task :send_messages_to_all => :environment do
    app    = ENV['app'] ||= 'all' 
    count  = ENV['n']   ||= '5'
    actual = 0
    Mbus::Io.initialize(app, init_options)
    Mbus::Config.exchange_entries_for_app(app).each { | entry |
      exch_name = entry['name']
      Mbus::Config::queues_for_app(app).each { | queue_entry | 
        if exch_name = queue_entry['exch']
          count.to_i.times do | i |
            actual = actual + 1
            uwk  = unwild_key(queue_entry['key'])
            body = "Msg #{actual} sent to exch '#{exch_name}' key: '#{uwk}'"
            msg  = create_message(actual, body) 
            Mbus::Io.send_message(exch_name, msg.to_json, uwk)
          end  
        end
      }
    }
    Mbus::Io.shutdown
  end
  
  desc "Read messages from all exchanges and keys, n="
  task :read_messages_from_all => :environment do
    app    = ENV['app'] ||= 'all' 
    count  = ENV['n']   ||= '5'
    actual = 0
    Mbus::Io.initialize(app, init_options)
    Mbus::Config.exchange_entries_for_app(app).each { | entry |
      exch_name = entry['name']
      Mbus::Config::queues_for_app(app).each { | queue_entry |
        if exch_name = queue_entry['exch']
          read_loop(exch_name, queue_entry['name'], count)
        end
      }
    }
    Mbus::Io.shutdown
  end 

  desc "Delete the given exchange, e="
  task :delete_exchange => :environment do
    app  = ENV['app'] ||= 'all'
    opts = init_options
    opts[:initialize_exchanges] = false
    Mbus::Io.initialize(app, opts)
    exch_name = ENV['e']
    if exch_name
      result = Mbus::Io.delete_exchange(exch_name, {})
      puts "result for deleting exchange '#{exch_name}' = #{result}"
    else
      puts "No exchange name provided, use the e= arg."
    end
  end
  
  desc "Start the SampleConsumerProcess"
  task :sample_process => :environment do
    ENV['MBUS_APP'] = ENV['app'] ||= 'logging-consumer'
    Mbus::SampleConsumerProcess.new.process_loop
  end 
  
end 

def init_options
  opts = {}
  opts[:verbose] = true
  opts[:silent]  = false
  opts[:rabbitmq_url] = ENV['rabbitmq_url'] if ENV['rabbitmq_url'] 
  opts[:start_bunny]  = ENV['start_bunny']  if ENV['start_bunny']
  opts[:initialize_exchanges] = ENV['init_exchanges'] if ENV['init_exchanges']
  opts
end

def to_bool(s)
  s.to_s.downcase == 'true'
end

def unwild_key(s)
  s.tr('*#','xx')
end

def create_message(seq, body='hello')
  msg = {}
  msg['seq'] = seq 
  msg['body'] = body 
  msg['sent_at'] = Time.now.to_f
  msg
end

def read_loop(ename, qname, count)
  continue_to_process, actual = true, 0
  while continue_to_process
    msg = Mbus::Io.read_message(ename, qname)
    if msg && (msg != :queue_empty)
      Mbus::Io.ack_queue(ename, qname)
    end  
    if (msg == :queue_empty) || msg.nil?
      continue_to_process = false
      puts "exch: #{ename} queue: #{qname} - empty"
    else
      actual = actual + 1
      puts "exch: #{ename} queue: #{qname} - msg #{actual}: #{msg}"
    end
    if actual >= count.to_i
      continue_to_process = false
    end
  end
end

