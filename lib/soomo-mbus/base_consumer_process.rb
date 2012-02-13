module Mbus

  # :markup: tomdoc
  #
  # Internal: 
  #
  # Chris Joakim, Locomotive LLC, 2012/02/13
  
  class BaseConsumerProcess

    attr_reader :exchange_name, :queue_name, :sleep_time
    attr_reader :continue_to_process, :messages_read, :verbose 
    attr_reader :db_disconnected_count, :db_disconnect_sleep_time
    
    def default_exchange
      'soomo'
    end
    
    def default_queue
      nil
    end
    
    def initialize
      base_initialize
    end 
    
    def base_initialize
      @exchange_name = ENV['EXCHANGE'] ||= default_exchange
      @queue_name    = ENV['QUEUE'] ||= default_queue
      if exchange_name.nil? || queue_name.nil?
        puts "#{classname}.base_initialize FATAL CONFIG ERROR - nil exchange and/or queue values: '#{exchange_name}', '#{queue_name}'.  Exiting..."
        exit
      end
      @verbose = to_bool(ENV['VERBOSE'])
      @sleep_time = init_queue_empty_sleep_time
      @continue_to_process = true
      @db_disconnect_sleep_time = init_db_disconnected_sleep_time
      @messages_read, @db_disconnected_count = 0, 0 
      puts "#{classname}.base_initialize exchange: #{exchange_name} queue: #{queue_name} st: #{sleep_time} db: #{database_url}"

      Mbus::Io.initialize
      establish_db_connection if use_database?
      puts "#{classname}.base_initialize completed"
    end

    def init_queue_empty_sleep_time
      value = ENV['SLEEP_TIME'] ||= '10'
      (value.downcase == 'stop') ? -1 : value.to_i
    end
    
    def init_db_disconnected_sleep_time
      value = ENV['DB_DISCONNECT_SLEEP_TIME'] ||= '15'
      value.to_i 
    end 

    def shutdown
      base_shutdown
    end
    
    def base_shutdown 
      puts "#{classname}.base_shutdown starting" 
      Mbus::Io.shutdown
      puts "#{classname}.base_shutdown completed"
    end
  
    def process_loop(test_mode=false)
      while continue_to_process
        @continue_to_process = false if test_mode
        msg = Mbus::Io.read_message(exchange_name, queue_name)
        if (msg == :queue_empty) || msg.nil?
          handle_no_message
        else
          handle_message(msg)
        end 
      end
    end
    
    def handle_no_message
      if sleep_time < 0
        puts "#{classname}.handle_no_message - no messages; terminating"
        @continue_to_process = false
      else
        puts "#{classname}.handle_no_message - no messages; sleeping #{sleep_time}"
        sleep sleep_time
      end 
    end
    
    def handle_message(msg)
      @messages_read = messages_read + 1
      puts "#{classname}.handle_message #{messages_read}: #{msg}"
      if use_database?
        ActiveRecord::Base.connection.verify!
        if database_connection_active?
          process_and_ack_message(msg)
        else
          handle_db_disconnect
        end
      else
        process_and_ack_message(msg)
      end
    end
    
    def handle_db_disconnect
      @db_disconnected_count = @db_disconnected_count + 1
      puts "#{classname}.handle_db_disconnect - count #{db_disconnected_count}; sleeping for #{db_disconnect_sleep_time}"
      sleep db_disconnect_sleep_time
    end

    def process_and_ack_message(msg)
      begin
        process_message(msg)
      rescue Exception => e
        excp = e
        puts "#{classname}.handle_message Exception #{e.class.name} #{e.message}"
      ensure
        Mbus::Io.ack_queue(exchange_name, queue_name) 
      end 
    end
    
    # Subclasses should override this method.
    def process_message(msg) 
      puts "#{classname}.process_message: #{msg.inspect}"
    end

    def classname
      self.class.name
    end

    def to_bool(s)
      s.to_s.downcase == 'true'
    end  
    
    def use_database?
      database_url != 'none'
    end
    
    def database_url
      env_var_name = ENV['DB'] ||= 'DATABASE_URL'
      (env_var_name.to_s.downcase == 'none') ? 'none' : ENV[env_var_name]
    end
    
    def database_connection_active?
      ActiveRecord::Base.connection.active?
    end

    def establish_db_connection
      db_url = database_url 
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
        puts "#{classname}.establish_db_connection - DB connection established to URL: #{db_url}"
      else
        puts "#{classname}.establish_db_connection - WARNING: DB connection NOT established to URL: #{db_url}"
      end 
    end

  end
  
end
