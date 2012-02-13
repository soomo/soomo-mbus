module Mbus

  # :markup: tomdoc
  #
  # Public: This module, Mbus::Producer, is intended to be used or mixed-in
  # by classes which need to put messages on the message bus.
  #
  # Chris Joakim, Locomotive LLC, 2012/02/11
    
  module Producer

    # Public: Enqueue a message on the bus, based on the self/receiver
    # object, and the given options Hash.
    #
    # opts  - A Hash containing optional values.
    #   opts[:action]  - indicates the action on self, such as 'create', 'update', 
    #                   'delete' or non-CRUD function.
    #   opts[:message] - use the given message to put on the bus, rather than
    #                    having this module auto-format the JSON message.
    #   opts[:queue]   - explicitly specify a given rabbitmq target queue,
    #                    rather than having this module infer it.
    #
    # Returns either true or false, indicating if the message was enqueued. 
    
    def enqueue_on_bus(opts={})
      begin
        # put a message, derived from self, on the bus
        msg = format_msg(opts) 
        puts "enqueue_on_bus: #{msg}"
        Mbus::Io.send_activity_message(msg)
        true
      rescue Exception => e
        puts "Producer#enqueue_on_bus error", "#{self.inspect} opts: #{opts.inspect} e: #{e.inspect}"
        false
      end
    end

    # Internal: Auto-format a JSON message for the bus, based on the 
    # self/receiver object, and the given options Hash.
    #
    # opts  - A Hash containing optional values.
    # Returns a String in JSON format, suitable for sending as a rabbitmq message.
    
    def format_msg(opts={})
      if opts[:message]
        return opts[:message] # the sender formatted their own message; use it
      end
      msg = {}
      msg['class'] = self.class.name
      msg['v'] = Mbus::VERSION
      
      if self.kind_of?(ActiveRecord::Base)
        msg['id']      = self.id
        msg['action']  = opts[:action] 
        msg['app']     = opts[:app]
        msg['sent_at'] = Time.now.to_f
      end
      msg.to_json
    end
    
  end
  
end
