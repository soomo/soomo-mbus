module Mbus

  # :markup: tomdoc
  #
  # Internal: 
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/02/26
  
  class BaseConsumerProcess
    
    attr_reader :options, :app_name, :continue_to_process, :cycles
    attr_reader :queues_list, :messages_read, :messages_processed
    attr_reader :sleep_count, :max_sleeps
    attr_reader :queue_empty_sleep_time, :db_disconnected_count, :db_disconnect_sleep_time
    
    def initialize(opts={})
      base_initialize(opts)
    end 
    
    def base_initialize(opts={})
      @options  = opts
      @app_name = ENV['MBUS_APP']
      Mbus::Io.initialize(app_name, options)
      @continue_to_process      = true
      @cycles                   = 0
      @messages_read            = 0
      @messages_processed       = 0
      @db_disconnected_count    = 0
      @sleep_count              = 0
      @db_disconnect_sleep_time = initialize_db_disconnected_sleep_time
      @queue_empty_sleep_time   = initialize_queue_empty_sleep_time
      @queues_list              = initialize_queues_list
      @max_sleeps               = initialize_max_sleeps 
      if queues_list.size < 1
        @continue_to_process = false
        puts "#{log_prefix}.base_initialize Error - no queues defined for this app name" unless silent? 
      else
        unless test_mode?
          Mbus::Io.start  
          establish_db_connection if use_database?
        end
        puts "#{log_prefix}.base_initialize completed" unless silent? 
      end
    end

    def initialize_db_disconnected_sleep_time 
      value = ENV['MBUS_DBC_TIME'] ||= '20'
      value.to_i 
    end

    def initialize_queue_empty_sleep_time
      value = ENV['MBUS_QE_TIME'] ||= '15'
      (value.downcase == 'stop') ? -1 : value.to_i
    end 
    
    def initialize_queues_list
      wrapper_list = []
      Mbus::Config::queues_for_app(app_name).each { | entry |
        wrapper_list << Mbus::QueueWrapper.new(entry)
      }
      wrapper_list
    end
    
    def initialize_max_sleeps
      value = ENV['MBUS_MAX_SLEEPS'] ||= '-1'
      value.to_i 
    end
    
    def test_mode?
      @options[:test_mode] # presence = truth
    end
    
    def verbose?
      @options[:verbose] && @options[:verbose] == true
    end
    
    def silent?
      @options[:silent] && @options[:silent] == true
    end 

    def shutdown
      base_shutdown
    end
    
    def base_shutdown 
      puts "#{log_prefix}.base_shutdown starting" unless silent? 
      Mbus::Io.shutdown
      puts "#{log_prefix}.base_shutdown completed" unless silent?
    end
  
    def process_loop
      while continue_to_process
        @continue_to_process = false if test_mode?
        @cycles = cycles + 1
        if database_ok?
          queues_list.each { | qw |
            if qw.should_read?
              json_msg_str = Mbus::Io.read_message(qw.exch, qw.name)
              if (json_msg_str == :queue_empty) || json_msg_str.nil?
                handle_no_message(qw)
              else
                @messages_read = messages_read + 1
                process_and_ack_message(qw, json_msg_str)
              end
            end
          }
          go_to_sleep('process_loop - cycle queue(s) empty', queue_empty_sleep_time) if should_sleep?
        end 
      end
    end
    
    def database_ok?
      ok = false
      if use_database?
        begin
          ActiveRecord::Base.connection.verify!
          ok = ActiveRecord::Base.connection.active?
        rescue Exception => e
          puts "#{log_prefix}.database_ok? cycle #{cycles} - DB Exception #{e.inspect}" unless silent?
          go_to_sleep('check_database - exception', db_disconnect_sleep_time)
        end
        
        unless ok
          @db_disconnected_count = db_disconnected_count + 1 
          go_to_sleep('check_database - not active', db_disconnect_sleep_time)
          establish_db_connection  # try to reconnect after sleeping a while
        end 
      else
        ok = true
      end
      ok
    end
    
    def should_sleep?
      queues_list.each { | qw | return false if qw.should_read? }
      true 
    end

    def go_to_sleep(method, time)
      @sleep_count = sleep_count + 1    
      msg = "cycle #{cycles}, sleep # #{sleep_count} for #{time}, mr: #{messages_read}, mp: #{messages_processed} ddc: #{db_disconnected_count}"
      if max_sleeps < 0
        puts "#{log_prefix}.#{method} - #{msg}" unless silent?
        sleep(time)
      else
        if sleep_count >= max_sleeps
          @continue_to_process = false
        else
          puts "#{log_prefix}.#{method} - #{msg}" unless silent? 
          sleep(time)
        end
      end 
    end
    
    def handle_no_message(qw)
      qw.next_read_time!(queue_empty_sleep_time)
      if queue_empty_sleep_time < 0
        puts "#{log_prefix}.handle_no_message - no messages; terminating" unless silent?
        @continue_to_process = false
      end 
    end 
    
    def process_and_ack_message(qw, json_msg_str)
      begin
        process_message(qw, json_msg_str)
      rescue Exception => e
        puts "#{log_prefix}.process_and_ack_message Exception #{e.class.name} #{e.message}" unless silent? 
      ensure
        Mbus::Io.ack_queue(qw.exch, qw.name) if qw.ack?
      end 
    end
    
    def process_message(qw, json_msg_str)
      # Dynamically create and invoke a message handler class.
      # All message hander class names are in the form: OooAaaMessageHandler - where
      # Ooo is the "object" value in the message (i.e. - classname, ex. - 'Student'),
      # and Aaa is the "action" value in the message (ex. - 'created').  
      # Message handler classes should extend Mbus::BaseMessageHandler, and implement 
      # the "handle(msg_hash)" method, where the arg a message Hash object. 
      begin
        puts "#{log_prefix}.process_message: #{json_msg_str.inspect}" if verbose?
        msg_hash = JSON.parse(json_msg_str)
        handler = Object.const_get(handler_classname(msg_hash)).new(options)
        handler.handle(msg_hash)
        @messages_processed = messages_processed + 1
      rescue Exception => e
        puts "#{log_prefix}.process_message Exception exch: #{qw.exch} queue: #{qw.name} #{e.class.name} #{e.message}" unless silent? 
      end
    end
    
    def handler_classname(msg_hash)
      if msg_hash && msg_hash.class == Hash
        klass, action = msg_hash['object'], msg_hash['action']
        "#{klass}#{action.capitalize}MessageHandler"
      else
        nil
      end 
    end

    def classname
      self.class.name
    end
    
    def log_prefix
      "#{app_name} #{classname}"
    end 
    
    def use_database?
      database_url != 'none'
    end
    
    def database_url
      env_var_name = ENV['MBUS_DB'] 
      env_var_name = 'DATABASE_URL' if env_var_name.nil?
      (env_var_name.to_s.downcase == 'none') ? 'none' : ENV[env_var_name]
    end
    
    def database_connection_active?
      (use_database?) ? ActiveRecord::Base.connection.active? : false
    end

    def establish_db_connection
      db_url = database_url
      if db_url == 'none'
        false
      else 
        db = URI.parse(db_url)
        ActiveRecord::Base.establish_connection(
          :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
          :host     => db.host,
          :username => db.user,
          :password => db.password,
          :database => db.path[1..-1],
          :encoding => 'utf8'
        )
        if ActiveRecord::Base.connection && ActiveRecord::Base.connection.active?
          puts "#{log_prefix}.establish_db_connection - DB connection established to URL: #{db_url}" unless silent?
          true
        else
          puts "#{log_prefix}.establish_db_connection - WARNING: DB connection NOT established to URL: #{db_url}" unless silent?
          false
        end
      end 
    end

  end
  
end
