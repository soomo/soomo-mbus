module Mbus 

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::Config, is be used to obtain configuration
  # values used in this gem, such as for rabbitmq.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/02/14 

  class Config

    DEFAULT_CONFIG_ENV_VAR = 'MBUS_CONFIG_DEFAULT'
    
    @@options, @@config_env_var_name, @@config_value = {}, nil, ''

    def self.initialize(opts={})
      @@options = opts
      if custom_env_var_name != nil
        @@config_env_var_name = custom_env_var_name
        @@config_value = ENV[@@config_env_var_name]
        return if @@config_value
      end
      @@config_env_var_name = DEFAULT_CONFIG_ENV_VAR
      @@config_value = ENV[@@config_env_var_name]
    end
    
    def self.custom_env_var_name
      return if @@options[:mbus_env_var] if @@options[:mbus_env_var]
      return ENV['MBUS_ENV'].strip if ENV['MBUS_ENV']
      nil
    end

    def self.config_env_var_name
      @@config_env_var_name
    end
    
    def self.config_value
      @@config_value
    end 
    
    def self.initialize_exchanges?
      return true if @@options[:action].to_s == 'status'
      (@@options[:initialize_exchanges].to_s == 'false') ? false : true
    end
    
    def self.is_consumer?(exch_name)
      return true if @@options[:action].to_s == 'status' 
      exchanges.each { | ename |
        if ename == exch_name.to_s
          exch_entries(ename).each { | entry |
            if entry.consume?
              return true
            end 
          }
        end
      }
      false 
    end

    def self.consumer_exchange
      exchanges[0]
    end
    
    def self.consumer_queue
      exch_entries(consumer_exchange)[0].queue
    end
    
    def self.rabbitmq_url
      return @@options[:rabbitmq_url] if @@options[:rabbitmq_url]
      ENV['RABBITMQ_URL'] ||= 'amqp://localhost'
    end  
    
    def self.entry_delimiter
      '/'
    end 
    
    def self.entry_field_delimiter
      ','
    end 
    
    def self.exchanges
      exchanges = []
      @@config_value.to_s.split(entry_delimiter).each { | entry_value |
        entry = ConfigEntry.new(entry_value)
        exchanges << entry.exchange if entry.valid?
      }
      exchanges.uniq
    end
    
    def self.exch_entries(exch_name)
      entries = []
      @@config_value.to_s.split(entry_delimiter).each { | entry_value |
        entry = ConfigEntry.new(entry_value)
        if entry.valid? && (exch_name.to_s == entry.exchange)
          entries << entry
        end  
      }
      entries
    end 
    
  end
  
end