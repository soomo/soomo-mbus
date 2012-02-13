module Mbus 

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::Config, is be used to obtain configuration
  # values used in this gem, such as for rabbitmq.
  #
  # Chris Joakim, Locomotive LLC, 2012/02/13

  class Config

    def self.rabbitmq_url
      ENV['RABBITMQ_URL'] ||= 'amqp://localhost'
    end  
    
    def self.mbus_config
      ENV['MBUS_CONFIG']
    end
    
    def self.entry_delimiter
      '/'
    end 
    
    def self.entry_field_delimiter
      ','
    end 
    
    def self.exchanges
      config, exchanges = ENV['MBUS_CONFIG'], ['soomo']
      if config
        config.split(entry_delimiter).each { | entry_value |
          entry = ConfigEntry.new(entry_value)
          exchanges << entry.exchange if entry.valid?
        }
      end
      exchanges.uniq
    end
    
    def self.exch_entries(exch_name)
      config, entries = ENV['MBUS_CONFIG'], []
      if config
        config.split(entry_delimiter).each { | entry_value |
          entry = ConfigEntry.new(entry_value)
          if entry.valid? && (exch_name.to_s == entry.exchange)
            entries << entry
          end
        }
      end
      entries
    end 
    
  end
  
end