module Mbus

  # :markup: tomdoc
  #
  # Internal: This class us used within a rake task to create the JSON
  # value for the centralized MBUS_CONFIG value.
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/02/27
  
  class ConfigBuilder
  
    attr_reader :options, :root, :exchanges, :queues, :business_functions
    attr_reader :consumer_processes
    
    def initialize(opts={})
      @root, @options = {}, opts
      @exchanges, @queues,  = [], []
      @business_functions, @consumer_processes = [], []
      root[:version]   = options[:version] ||= Time.now.to_s
      root[:exchanges] = exchanges
      root[:queues]    = queues 
      root[:business_functions] = business_functions
      root[:consumer_processes] = consumer_processes
    end
    
    def build
      build_exchanges
      build_business_functions
      build_queues
      build_consumer_processes
      JSON.pretty_generate(root)
    end

    def build_exchanges 
      defaults = {:type => 'topic', :persistent => true, :mandatory => false, :immediate => false}
      required_keys = [:name, :type, :persistent]
      specifications = [
        {:name => 'soomo'},
        {:name => 'logs', :persistent => false}
      ]
      specifications.each { | spec |
        obj = apply_defaults(spec, defaults)
        exchanges << obj if valid?('exchange', obj, required_keys)
      }
    end
    
    def build_business_functions
      defaults = {:exch => default_root_routing_key}
      required_keys = [:exch, :app, :object, :action, :routing_key]
      specifications = [
        {:app => 'core', :object => 'grade',   :action => 'create'}, 
        {:app => 'core', :object => 'grade',   :action => 'update'}, 
        {:app => 'core', :object => 'grade',   :action => 'exception'}, 
        {:app => 'core', :object => 'student', :action => 'create'}, 
        {:app => 'core', :object => 'student', :action => 'update'},
        {:app => 'core', :object => 'student', :action => 'destroy'}, 
        {:app => 'core', :object => 'student', :action => 'exception'},
        
        {:app => 'sle',  :object => 'grade',   :action => 'create'},
        {:app => 'sle',  :object => 'grade',   :action => 'update'}, 
        {:app => 'sle',  :object => 'grade',   :action => 'exception'}, 
        {:app => 'sle',  :object => 'hash',    :action => 'grade_broadcast'}, 
        
        {:app => 'discussions',  :object => 'discussion', :action => 'create'},
        {:app => 'discussions',  :object => 'discussion', :action => 'comment'},
        {:app => 'discussions',  :object => 'discussion', :action => 'exception'},
        
        {:exch => 'logs', :app => 'core', :object => 'string', :action => 'logmessage'},
        {:exch => 'logs', :app => 'core', :object => 'hash',   :action => 'logmessage'}, 
        {:exch => 'logs', :app => 'sle',  :object => 'string', :action => 'logmessage'}, 
        {:exch => 'logs', :app => 'cac',  :object => 'string', :action => 'logmessage'} 
      ]
      specifications.each { | spec |
        obj = business_function(spec, defaults)
        business_functions << obj if valid?('business_function', obj, required_keys)
      } 
    end
    
    def build_queues
      defaults = {:exch => default_exchange, :durable => true, :ack => true}
      required_keys = [:exch, :name, :durable, :ack, :key]
      specifications = [
        {:name => 'analytics-grade',   :key => '#.object-grade.#'},
        {:name => 'blackboard-grade',  :key => '#.action-grade_broadcast'},  
        {:name => 'analytics-student', :key => '#.object-student.#'}, 
        {:name => 'sle-student',       :key => '#.object-student.#'}, 
        {:name => 'sle-discussion',    :key => '#.object-discussion.#'},
        {:name => 'alerts-exception',  :key => '#.action-exception'}, 
        {:exch => 'logs', :name => 'messages', :ack => false, :key => '#.action-logmessage'}
      ]
      specifications.each { | spec |
        obj = apply_defaults(spec, defaults)
        queues << obj if valid?('queue', obj, required_keys)
      }
    end
    
    def build_consumer_processes
      defaults = {}
      required_keys = [:name, :queues]
      specifications = [
        {:app => 'analytics', :name => 'analytics-consumer', 
         :queues => ['soomo|analytics-grade', 'soomo|analytics-student']},

        {:app => 'sle', :name => 'sle-consumer', 
         :queues => ['soomo|sle-student', 'soomo|sle-discussion']}, 
         
        {:app => 'bb-pusher', :name => 'bb-pusher-consumer', 
         :queues => ['soomo|blackboard-grade']},
         
        {:app => 'logging', :name => 'logging-consumer',
         :queues => ['logs|messages']}, 
      ]
      specifications.each { | spec |
        obj = apply_defaults(spec, defaults)
        consumer_processes << obj if valid?('consumer_process', obj, required_keys)
      }
    end

    def default_exchange
      @options[:default_exchange] ||= ''
    end
    
    def default_root_routing_key 
      exch = @options[:default_exchange].to_s.strip
      (exch.size > 0) ? exch : 'root'
    end  
    
    def boolean(value, default_value)
      return default_value if value.nil?
      return value if (value == true) || (value == false)
      value.to_s.downcase == 'true'
    end
    
    def apply_defaults(spec, defaults)
      defaults.keys.each { | key |
        spec[key] = defaults[key] unless spec[key]
      }
      spec
    end
    
    def business_function(spec, defaults)
      spec = apply_defaults(spec, defaults)
      obj, app, object, action = spec[:exch], spec[:app], spec[:object], spec[:action]
      spec[:routing_key] = "#{obj}.app-#{app}.object-#{object}.action-#{action}"
      spec
    end
    
    def valid?(config_type, opts={}, keys=[], verbose=true)
      result = true
      keys.each { | key | 
        if opts[key].nil?
          result = false
          puts "missing key #{key} in config type #{config_type}" if verbose
        end
      }
      result
    end
    
  end
  
end