module Mbus

  # :markup: tomdoc
  #
  # Internal: Instances of this class represent one of the /-delimited
  # values within the MBUS_CONFIG environment varible.  Each instance
  # contains an exchange name, a queue name, and a queue-binding string.
  #
  # Chris Joakim, Locomotive LLC, 2012/02/11 
  
  class ConfigEntry
  
    attr_reader :raw_value, :exchange, :queue, :bind_key

    # Public: Enqueue a message on the bus, based on the self/receiver
    # object, and the given options Hash.
    #
    # s  - A string value parsed from the value of the MBUS_CONFIG
    #      environment variable.  For example: 'soomo,response,response.*'.
    #
    # Returns a new instance of class Mbus::ConfigEntry; it may or may not be valid.
    
    def initialize(s='')
      if s
        @raw_value = s
        tokens = s.split(Mbus::Config.entry_field_delimiter)
        if tokens.size > 2
          @exchange, @queue, @bind_key = tokens[0].strip, tokens[1].strip, tokens[2].strip
        end
      end
    end
    
    # Return boolean true or false, representing the validity of this instance.
    
    def valid?
      return false if @exchange.nil?
      return false if @queue.nil?
      return false if @bind_key.nil?
      true
    end

    # Return a String value which concatinates the exchange name, a vertibar delimiter,
    # and the queue name.  This is the "fully-qualified" queue name.
    
    def fullname
      "#{@exchange}|#{@queue}"
    end 
    
  end
  
end