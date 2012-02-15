module Mbus

  # :markup: tomdoc
  #
  # Internal: Instances of this class represent one of the /-delimited
  # values within a MBUS_CONFIG_xxx environment varible.  Each instance
  # contains an exchange name, a queue name, and a queue-binding string.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/02/14 
  
  class ConfigEntry
  
    attr_reader :raw_value, :exchange, :queue, :consume, :bind_key

    # Public: Enqueue a message on the bus, based on the self/receiver
    # object, and the given options Hash.
    #
    # s  - A string value parsed from the value of a MBUS_CONFIG_xxx
    #      environment variable.  For example: 'soomo,response,consume,response.*'.
    #
    # Returns a new instance of class Mbus::ConfigEntry; it may or may not be valid.
    
    def initialize(s='')
      if s
        @raw_value = s
        tok = s.split(Mbus::Config.entry_field_delimiter)
        if tok.size > 3
          @exchange, @queue, @consume, @bind_key = tok[0].strip, tok[1].strip, tok[2].downcase.strip, tok[3].strip
        end
      end
    end
    
    # Return boolean true or false, representing the validity of this instance.
    
    def valid?
      return false if exchange.nil?
      return false if queue.nil?
      return false if consume.nil?
      return false if bind_key.nil?
      true
    end 
    
    def consume?
      consume == 'consume'
    end
    
    def produce?
      (consume?) ? false : true
    end 

    # Return a String value which concatinates the exchange name, a vertibar delimiter,
    # and the queue name.  This is the "fully-qualified" queue name.
    
    def fullname
      "#{@exchange}|#{@queue}"
    end 
    
    def to_s
      "ConfigEntry e: #{exchange} q: #{queue} pc: #{consume} bk: #{bind_key} rv: #{raw_value}"
    end
    
  end
  
end