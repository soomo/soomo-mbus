module Mbus 

  # :markup: tomdoc
  #
  # Internal: This class, Mbus::ConfigValidator, is ...
  #
  # Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

  class ConfigValidator

    attr_reader   :json_object
    attr_accessor :errors, :warnings  
    attr_reader   :exchange_names, :queue_names, :used_queue_names
    attr_reader   :business_function_names, :consumer_process_names
    
    def initialize(json_obj)
      @json_object, @errors, @warnings = json_obj, [], []
      @exchange_names, @queue_names, @used_queue_names = {}, {}, {}
      @business_function_names, @consumer_process_names = {}, {}
    end
    
    def valid?
      validate
      errors.size == 0
    end
    
    private
    
    def errors?
      errors.size > 0
    end
    
    def validate
      validate_root_object
      unless errors?
        validate_version
        validate_exchanges
        validate_queues
        validate_business_functions
        validate_consumer_processes
        report_unused_and_undefined_queues
      end
    end
    
    def validate_root_object
      if json_object.nil?
        errors << "the root json_object is nil"
        return
      end
      if json_object.class.name != 'Hash'
        errors << "the root json_object is not a Hash"
        return
      end
      required_root_keys.each { | key |
        unless json_object[key]
          errors << "the root json_object is missing key: #{key}"
        end
      }
    end

    def validate_version
      v = json_object['version']
      if v.class.name != 'String'
        errors << "the version value is not a String"
        return
      end
      if v.strip.size < 1
        errors << "the version value is too short"
        return
      end
    end
    
    def validate_exchanges
      key = 'exchanges'
      list = root_array(key)
      return if list.nil?
      if list.size < 1
        errors << "zero #{key} are defined"
      else
        list.each_with_index { | entry, idx |
          validate_entry('exchange', idx, entry, exchange_entry_spec)
          if entry.class == Hash
            name = entry['name'].to_s
            type = entry['type'].to_s
            
            if exchange_names.has_key?(name)
              errors << "duplicate exchange name #{name} at index #{idx}"
            else
              exchange_names[name] = :empty
            end
            unless valid_exchange_types.include?(type)
              errors << "invalid exchange type #{type} at index #{idx}"
            end
          end
        } 
      end
    end 
    
    def validate_queues
      key = 'queues'
      list = root_array(key)
      return if list.nil?
      if list.size < 1
        errors << "zero #{key} are defined"
      else
        list.each_with_index { | entry, idx |
          validate_entry('queues', idx, entry, queue_entry_spec)
          if entry.class == Hash
            exch, name = entry['exch'].to_s, entry['name'].to_s 
            full_name = "#{exch}|#{name}"
            if queue_names.has_key?(full_name)
              errors << "duplicate queue #{full_name} at index #{idx}"
            else
              queue_names[full_name] = :empty
            end
          end 
        } 
      end
    end
    
    def validate_business_functions
      key = 'business_functions'
      list = root_array(key)
      return if list.nil?  
      if list.size < 1
        errors << "zero #{key} are defined"
      else
        list.each_with_index { | entry, idx |
          validate_entry('business_function', idx, entry, business_function_entry_spec)
          if entry.class == Hash
            app, obj, act = entry['app'].to_s, entry['object'].to_s, entry['action'].to_s 
            full_name = "#{app}|#{obj}|#{act}"
            if business_function_names.has_key?(full_name)
              errors << "duplicate business_function #{full_name} at index #{idx}"
            else
              business_function_names[full_name] = :empty
            end
          end 
        } 
      end 
    end 
    
    def validate_consumer_processes
      key = 'consumer_processes'
      list = root_array(key)
      return if list.nil?
      if list.size < 1
        errors << "zero #{key} are defined"
      else
        list.each_with_index { | entry, idx |
          validate_entry('consumer_process', idx, entry, consumer_process_entry_spec)
          if entry.class == Hash
            app, name, queues = entry['app'].to_s, entry['name'].to_s, entry['queues']
            full_name = "#{app}|#{name}"
            unless name.include?('consumer')
              errors << "name should contain the literal 'consumer'"
            end
            if consumer_process_names.has_key?(full_name)
              errors << "duplicate consumer_process #{full_name} at index #{idx}"
            else
              consumer_process_names[full_name] = :empty
            end
            if (queues.nil?) || (queues.class.name != 'Array') || (queues.size < 1)
              errors << "consumer_process #{full_name} has no queues, or is not an Array"
            else
              queues.each { | fname | used_queue_names[fname] = :empty }
            end
          end 
        } 
      end 
    end
    
    def report_unused_and_undefined_queues
      queue_names.keys.sort.each { | fname |
        unless used_queue_names.has_key?(fname)
          warnings << "unused queue: #{fname}"
        end  
      }
      used_queue_names.keys.sort.each { | fname |
        unless queue_names.has_key?(fname)
          warnings << "undefined queue: #{fname}"
        end  
      } 
    end
    
    def validate_entry(type, idx, entry, entry_spec)
      if entry.class.name != 'Hash'
        errors << "#{type} at index #{idx} is not a Hash"
        return
      end
      entry_spec.keys.each { | key | 
        value = entry[key.to_s]
        if value.nil?
          errors << "#{type} at index #{idx} is missing key #{key}"
        elsif !is_valid_class?(value, entry_spec[key])
          errors << "#{type} at index #{idx}, #{key} is not a valid #{entry_spec[key]}"
        end
      }  
    end
    
    def required_root_keys
      %w(version exchanges queues business_functions consumer_processes)
    end
    
    def valid_exchange_types
      %w(direct topic headers fanout)
    end
    
    def exchange_entry_spec
      {'name' => 'String', 'type' => 'String', 'persistent' => 'bool', 'mandatory' => 'bool', 'immediate' => 'bool'}
    end
    
    def queue_entry_spec
      {'name' => 'String', 'exch' => 'String', 'key' => 'String', 'durable' => 'bool', 'ack' => 'bool'}
    end
      
    def business_function_entry_spec
      {'app' => 'String', 'object' => 'String', 'action' => 'String', 'exch' => 'String', 'routing_key' => 'String'}
    end

    def consumer_process_entry_spec
      {'app' => 'String', 'name' => 'String', 'queues' => 'Array'}
    end 
      
    def root_array(key)
      list = json_object[key]
      if list.class.name != 'Array'
        errors << "the root #{key} entry is not an Array"
        nil
      else
        list
      end 
    end 
    
    def is_valid_class?(value, klazz)
      if (klazz.downcase == 'bool') || (klazz.downcase == 'boolean')
        return true if value.class.name == 'TrueClass'
        return true if value.class.name == 'FalseClass'
        false
      else
        if klazz.downcase == value.class.name.downcase
          if value.class.name == 'String'
            value.strip.size > 0
          else
            value.size > 0
          end
        else
          false
        end
      end
    end
    
  end
  
end

=begin

=end