module Mbus

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::Io, is used to perform Io with rabbitmq. 
  #
  # Chris Joakim, Locomotive LLC, 2012/02/13

  class Io 
    
    @@exchanges, @@queues = {}, {}
    
    def self.initialize(is_consumer=true, init_exchanges=true)
      @@url = Mbus::Config.rabbitmq_url
      config = Mbus::Config.mbus_config
      puts "Mbus::Io.initialize, URL: #{@@url} Config: #{config}"
      @@bunny = Bunny.new(@@url)
      @@bunny.start
      if init_exchanges
        Mbus::Config.exchanges.each { | exch_name |
          initialize_exchange(exch_name, is_consumer)
        }
      end
      puts "Mbus::Io.initialize complete - exchanges: #{@@exchanges.size}, queues: #{@@queues.size}"
    end
    
    def self.initialize_exchange(exch_name, is_consumer=true)
      exchange = @@bunny.exchange(exch_name, {:type => :topic})
      if exchange
        @@exchanges[exch_name] = exchange
        puts "Mbus::Io.initialize_exchange - created exchange '#{exch_name}'"
        if is_consumer
          entries = Mbus::Config.exch_entries(exch_name)
          entries.each { | entry |
            if @@queues[entry.fullname]
              puts "WARNING Mbus::Io.initialize_exchange - already bound '#{entry.fullname}'"
            else
              queue = @@bunny.queue(entry.queue, {:durable => true})
              queue.bind(exchange, :key => entry.bind_key)
              @@queues[entry.fullname] = queue
              puts "Mbus::Io.initialize_exchange - bound fname '#{entry.fullname}' to '#{entry.bind_key}'" 
            end 
          }
        end 
      end
    end
    
    def self.delete_exchange(exch_name, opts = {})
      exchange = @@bunny.exchange(exch_name, {:type => :topic})
      (exchange.nil?) ? nil : exchange.delete(opts)
    end
    
    def self.send_message(exch_name, msg, routing_key)
      result, exchange = false, @@exchanges[exch_name.to_s]
      if exchange && msg && routing_key
        exchange.publish(msg, {:key => routing_key, :persistent => true})
        result = true
        puts "Mbus::Io.send_message, exch: '#{exch_name}' key: '#{routing_key}' msg: #{msg}"
      end
      result
    end 
    
    def self.read_message(exch_name, qname)
      fname = fullname(exch_name, qname)
      queue = @@queues[fname]
      if queue
        queue.pop(:ack => true, :nowait => true)[:payload]
      else
        puts "WARNING Mbus::Io.read_message exch/queue not defined: #{fname}"
      end
    end

    def self.ack_queue(exch_name, qname)
      fname = fullname(exch_name, qname)
      queue = @@queues[fname]
      queue.ack if queue
    end
    
    def self.queue_status(exch_name, qname)
      fname = fullname(exch_name, qname)
      queue = @@queues[fname]
      queue.status if queue 
    end
    
    def self.status
      hash = {}
      @@queues.keys.sort.each { | fname |
        queue = @@queues[fname]
        hash[fname] = queue.status if queue
      }
      hash
    end

    def self.shutdown
      puts "Mbus::Io.shutdown..."
      @@bunny.stop
      puts "Mbus::Io.shutdown completed."
    end
    
    def self.fullname(exch_name, qname)
      "#{exch_name.to_s}|#{qname.to_s}"
    end
    
    def exchanges
      @@exchanges
    end
    
    def queues
      @@queues
    end 
    
  end
  
end