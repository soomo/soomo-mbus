require 'spec_helper'

# rake spec SPEC=spec/config_validator_spec.rb

describe Mbus::ConfigValidator do

  describe "the root JSON object" do 
  
    it 'should not validate a nil root JSON object' do
      validate_config_object(nil, false, ['the root json_object is nil'])
    end
  
    it 'should not validate an Array root JSON object' do
      validate_config_object([], false, ['the root json_object is not a Hash']) 
    end

    it 'should not validate an empty Hash root JSON object' do
      validate_config_object({}, false, [
        "the root json_object is missing key: version", 
        "the root json_object is missing key: exchanges", 
        "the root json_object is missing key: queues", 
        "the root json_object is missing key: business_functions",
        "the root json_object is missing key: consumer_processes"])
    end
    
    it 'should not validate a JSON object with empty collections' do
      json_obj = {}
      json_obj['version'] = ''
      json_obj['exchanges'] = []
      json_obj['queues'] = []
      json_obj['business_functions'] = []
      json_obj['consumer_processes'] = []
      validate_config_object(json_obj, false, [
        "the version value is too short",
        "zero exchanges are defined",
        "zero queues are defined",
        "zero business_functions are defined",
        "zero consumer_processes are defined"]) 
    end

    it 'should not validate an invalid version entry' do 
      json_obj = JSON.parse(test_config_json)
     
      json_obj['version'] = []
      validate_config_object(json_obj, false, ['the version value is not a String']) 
    
      json_obj['version'] = '  '
      validate_config_object(json_obj, false, ['the version value is too short']) 
    end 
  
    it 'should validate the standard test JSON' do 
      json_obj = JSON.parse(test_config_json)
      validate_config_object(json_obj, true, []) 
    end
  
  end 

  describe "the four root element collections must be Arrays" do
  
    it 'the exchanges should be an Array' do
      json_obj = JSON.parse(test_config_json)
      json_obj['exchanges'] = {}
      validate_config_object(json_obj, false, ['the root exchanges entry is not an Array'])
    end
  
    it 'the queues should be an Array' do 
      json_obj = JSON.parse(test_config_json)
      json_obj['queues'] = {} 
      validate_config_object(json_obj, false, ['the root queues entry is not an Array']) 
    end
  
    it 'the business_functions should be an Array' do  
      json_obj = JSON.parse(test_config_json)
      json_obj['business_functions'] = {}
      validate_config_object(json_obj, false, ['the root business_functions entry is not an Array'])
    end 
  
    it 'the consumer_processes should be an Array' do 
      json_obj = JSON.parse(test_config_json)
      json_obj['consumer_processes'] = {} 
      validate_config_object(json_obj, false, ['the root consumer_processes entry is not an Array']) 
    end 
  
  end 

  describe "the four root element Arrays must contain valid elements" do
     
    it 'should not validate invalid exchange entries' do
      json_obj = JSON.parse(test_config_json)
      exchanges = []
      exchanges << []
      exchanges << {}
      exchanges << {'name' => false, 'type' => 5, 'persistent' => [],
                    'mandatory' => 'x', 'immediate' => 6}                       # invalid - data types
      exchanges << {'nam'  => 'test', 'type' => 'wrong',  'persistent' => true} # invalid - missing values
      exchanges << {'name' => 'test', 'type' => 'topic',  'persistent' => true,
                    'mandatory' => true, 'immediate' => false}                  # <= valid
      exchanges << {'name' => 'test', 'type' => 'topic',  'persistent' => true,
                    'mandatory' => true, 'immediate' => false}                  # <= duplicate 
      exchanges << {'name' => 'fan', 'type' => 'fanout',  'persistent' => true,
                    'mandatory' => true, 'immediate' => false}                  # <= valid 
      exchanges << {'name' => 'dir', 'type' => 'direct',  'persistent' => true,
                    'mandatory' => true, 'immediate' => false}                  # <= valid 
      exchanges << {'name' => 'head', 'type' => 'headers',  'persistent' => true,
                    'mandatory' => false, 'immediate' => true}                  # <= valid 
      
      json_obj['exchanges'] = exchanges 
      validate_config_object(json_obj, false, [
        "exchange at index 0 is not a Hash",
        "exchange at index 1 is missing key name",
        "exchange at index 1 is missing key type",
        "exchange at index 1 is missing key persistent",
        "exchange at index 1 is missing key mandatory",
        "exchange at index 1 is missing key immediate",
        "invalid exchange type  at index 1",
        "exchange at index 2, name is not a valid String",
        "exchange at index 2, type is not a valid String",
        "exchange at index 2, persistent is not a valid bool",
        "exchange at index 2, mandatory is not a valid bool",
        "exchange at index 2, immediate is not a valid bool",
        "invalid exchange type 5 at index 2",
        "exchange at index 3 is missing key name",
        "exchange at index 3 is missing key mandatory",
        "exchange at index 3 is missing key immediate",
        "duplicate exchange name  at index 3",
        "invalid exchange type wrong at index 3",
        "duplicate exchange name test at index 5"]) 
    end
    
    it 'should not validate invalid queue entries' do
      json_obj = JSON.parse(test_config_json)
      queues = []
      queues << []
      queues << {}
      queues << {'name' => false, 'exch' => 5, 'key' => 5, 'durable' => 5, 'ack' => 5 } 
      queues << {'name' => 'test', 'exch' => 'e1', 'key' => 'x.y.z', 
                 'durable' => true, 'ack' => false} # <= valid 
      queues << {'name' => 'test', 'exch' => 'e1', 'key' => 'x.y.z', 
                 'durable' => true, 'ack' => false} # <= duplicate 

      json_obj['queues'] = queues 
      validate_config_object(json_obj, false, [
        "queues at index 0 is not a Hash",
        "queues at index 1 is missing key name",
        "queues at index 1 is missing key exch",
        "queues at index 1 is missing key key",
        "queues at index 1 is missing key durable",
        "queues at index 1 is missing key ack",
        "queues at index 2, name is not a valid String",
        "queues at index 2, exch is not a valid String",
        "queues at index 2, key is not a valid String",
        "queues at index 2, durable is not a valid bool",
        "queues at index 2, ack is not a valid bool",
        "duplicate queue e1|test at index 4"]) 
    end 
    
    it 'should not validate invalid business_function entries' do
      json_obj = JSON.parse(test_config_json)
      business_functions = []
      business_functions << []
      business_functions << {}
      business_functions << {'app' => false, 'object' => 5, 'action' => 5, 
                             'exch' => 5, 'routing_key' => 5 } 
      business_functions << {'app' => 'app1', 'object' => 'Student', 'action' => 'created', 
                             'exch' => 'e1', 'routing_key' => 'a.b.c' } # valid 
      business_functions << {'app' => 'app1', 'object' => 'Student', 'action' => 'created', 
                             'exch' => 'e1', 'routing_key' => 'a.b.c' } # duplicate  
      
      json_obj['business_functions'] = business_functions 
      validate_config_object(json_obj, false, [
        "business_function at index 0 is not a Hash",
        "business_function at index 1 is missing key app",
        "business_function at index 1 is missing key object",
        "business_function at index 1 is missing key action",
        "business_function at index 1 is missing key exch",
        "business_function at index 1 is missing key routing_key",
        "business_function at index 2, app is not a valid String",
        "business_function at index 2, object is not a valid String",
        "business_function at index 2, action is not a valid String",
        "business_function at index 2, exch is not a valid String",
        "business_function at index 2, routing_key is not a valid String",
        "duplicate business_function app1|Student|created at index 4"]) 
    end

    it 'should not validate invalid consumer_processes entries' do
      json_obj = JSON.parse(test_config_json)
      consumer_processes = []
      consumer_processes << []
      consumer_processes << {}
      consumer_processes << {'app' => false, 'name' => 5, 'queues' => 5 } 
      consumer_processes << {'app' => 'app1', 'name' => 'queue_consumer', 
                             'queues' => ['q1', 'q2'] } # valid 
      consumer_processes << {'app' => 'app1', 'name' => 'queue_consumer', 
                             'queues' => ['q1', 'q2'] } # duplicate 
                             
      json_obj['consumer_processes'] = consumer_processes 
      validate_config_object(json_obj, false, [
        "consumer_process at index 0 is not a Hash",
        "consumer_process at index 1 is missing key app",
        "consumer_process at index 1 is missing key name",
        "consumer_process at index 1 is missing key queues",
        "name should contain the literal 'consumer'",
        "consumer_process | has no queues, or is not an Array",
        "consumer_process at index 2, app is not a valid String",
        "consumer_process at index 2, name is not a valid String",
        "consumer_process at index 2, queues is not a valid Array",
        "name should contain the literal 'consumer'",
        "consumer_process false|5 has no queues, or is not an Array",
        "duplicate consumer_process app1|queue_consumer at index 4"])
    end 

  end
  
end
