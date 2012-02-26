require 'spec_helper'

# rake spec SPEC=spec/config_spec.rb

describe Mbus::Config do

  before(:all) do
    set_local_redis_config
  end
  
  before(:each) do
    @opts = {:start_bunny => false, :verbose => false, :silent => true} 
    ENV['MBUS_APP']  = test_app_name
    ENV['MBUS_HOME'] = test_config_locations
  end

  it 'should implement method verbose?' do
    Mbus::Config.initialize('rspec_app', {:silent => true})
    Mbus::Config.verbose?.should be_false

    Mbus::Config.initialize('rspec_app', {:verbose => false, :silent => true})
    Mbus::Config.verbose?.should be_false 
    
    Mbus::Config.initialize('rspec_app', {:verbose => true, :silent => true})
    Mbus::Config.verbose?.should be_true 
  end 
  
  it 'should implement method silent?' do
    Mbus::Config.initialize('rspec_app', {:silent => true, :start_bunny => false})
    Mbus::Config.silent?.should be_true 
  end
  
  it 'should implement method log_prefix' do
    Mbus::Config.initialize('rspec_app', {:silent => true, :start_bunny => false})
    Mbus::Config.log_prefix.should == 'rspec_app Mbus::Config' 
  end
  
  it 'should have an application name based on MBUS_APP' do
    ENV['MBUS_APP'] = 'rspec_app5'
    Mbus::Config.initialize(nil, @opts)
    Mbus::Config.app_name.should == 'rspec_app5'
    
    ENV['MBUS_APP'] = nil 
    Mbus::Config.initialize(nil, @opts)
    Mbus::Config.app_name.should be_nil
  end
  
  it 'should implement method rabbitmq_url' do
    ENV['RABBITMQ_URL'] = nil
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.rabbitmq_url.should == 'amqp://localhost'
    
    ENV['RABBITMQ_URL'] = 'amqp://somehost:1234'
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.rabbitmq_url.should == 'amqp://somehost:1234' 
  end
  
  it 'should have configuration locations based on MBUS_HOME' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.config_locations.size.should == 2 
    Mbus::Config.config_locations[0].should == 'redis://localhost:6379/#MBUS_CONFIG_RSPEC' 
    Mbus::Config.config_locations[1].should == 'redis://localhost:6379/#MBUS_CONFIG_NOT_THERE'
    
    ENV['MBUS_HOME'] = nil 
    Mbus::Config.initialize(nil, @opts)
    Mbus::Config.config_locations.size.should == 0
  end 
  
  it 'should have routing_keys' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.routing_keys.keys.sort.each_with_index { | key, idx |
      entry = Mbus::Config.routing_keys[key]
      # puts "routing key: #{idx} #{key} = #{entry.inspect}"
    }
    Mbus::Config.routing_keys.size.should == 17
    entry = Mbus::Config.routing_keys['core|grade|create'] 
    entry['exch'].downcase.should   == 'soomo'
    entry['app'].downcase.should    == 'core' 
    entry['object'].downcase.should == 'grade'
    entry['action'].downcase.should == 'create'
    entry['routing_key'].downcase.should == 'soomo.app-core.object-grade.action-create'
    
    entry = Mbus::Config.routing_keys['core|hash|logmessage'] 
    entry['exch'].downcase.should   == 'logs'
    entry['app'].downcase.should    == 'core' 
    entry['object'].downcase.should == 'hash'
    entry['action'].downcase.should == 'logmessage'
    entry['routing_key'].downcase.should == 'logs.app-core.object-hash.action-logmessage' 
  end 

  it 'should implement method routing_lookup_key' do
    Mbus::Config.initialize('X25', @opts)
    'x25|hash|camelcase'.should == Mbus::Config.routing_lookup_key({},'camelCase')
    'x25|mbus::queuewrapper|create'.should == Mbus::Config.routing_lookup_key(Mbus::QueueWrapper.new,'create')
    
    Mbus::Config.initialize('core', @opts)
    'core|hash|message'.should == Mbus::Config.routing_lookup_key({},'message') 
    'core|string|message'.should == Mbus::Config.routing_lookup_key('','message') 
  end

  it 'should implement method lookup_routing_key' do
    Mbus::Config.initialize('core', @opts)
    Mbus::Config.lookup_routing_key({},'camelCase').should be_nil
    entry = Mbus::Config.lookup_routing_key({},'logmessage') 
    entry['exch'].should == 'logs'
    entry['routing_key'].should == 'logs.app-core.object-hash.action-logmessage'
    
    entry = Mbus::Config.lookup_routing_key('','logmessage')
    entry['exch'].should == 'logs'
    entry['routing_key'].should == 'logs.app-core.object-string.action-logmessage'
  end 
  
  it 'should implement method default_exchange_type' do
    Mbus::Config.default_exchange_type.should == 'topic'
  end
  
  it 'should implement method classname' do
    Mbus::Config.classname.should == 'Mbus::Config'
  end 
  
  it 'should implement method valid_config_json?' do
    Mbus::Config.valid_config_json?.should be_false
    Mbus::Config.valid_config_json?({}).should be_false
  end

  it 'should not allow method set_config to store an invalid value' do
    Mbus::Config.set_config('redis://localhost:6379/#MBUS_CONFIG_BAD', nil).should be_false
    Mbus::Config.set_config(nil, {}).should be_false
    Mbus::Config.set_config('redis://localhost:6379/#MBUS_CONFIG_BAD', 'non-json-value').should be_false 
  end
  
  it 'should implement method initialize_exchanges?' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.initialize_exchanges?.should be_true 
    
    Mbus::Config.initialize('rspec_app', {:action => 'status', :silent => true})
    Mbus::Config.initialize_exchanges?.should be_true 
    
    Mbus::Config.initialize('rspec_app', {:initialize_exchanges => 'false', :silent => true})
    Mbus::Config.initialize_exchanges?.should be_false 
    
    Mbus::Config.initialize('rspec_app', {:initialize_exchanges => false, :silent => true})
    Mbus::Config.initialize_exchanges?.should be_false

    Mbus::Config.initialize('rspec_app', {:initialize_exchanges => 'true', :silent => true})
    Mbus::Config.initialize_exchanges?.should be_true 
    
    Mbus::Config.initialize('rspec_app', {:initialize_exchanges => true, :silent => true})
    Mbus::Config.initialize_exchanges?.should be_true
  end 

  it 'should implement method is_consumer?' do 
    Mbus::Config.is_consumer?(nil).should be_false
    Mbus::Config.is_consumer?('all').should be_true
    Mbus::Config.is_consumer?('core').should be_false
    Mbus::Config.is_consumer?('undefined-consumer').should be_false 
    Mbus::Config.is_consumer?('sle-consumer').should be_true
    Mbus::Config.is_consumer?('logging-consumer').should be_true 
  end  

  it 'should implement method exchange' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.exchange(nil).should be_nil
    Mbus::Config.exchange('undefined').should be_nil 
    entry = Mbus::Config.exchange('logs')
    entry.class.should == Hash
    entry['name'].should == 'logs'
  end
  
  it 'should implement method exchange_entries_for_app' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.exchange_entries_for_app(nil).should == []
    Mbus::Config.exchange_entries_for_app('undefined').should == []

    list = Mbus::Config.exchange_entries_for_app('all')
    validate_exchange_list(list, ["logs", "soomo"]) 
    
    list = Mbus::Config.exchange_entries_for_app('core')
    validate_exchange_list(list, ["logs", "soomo"])
    
    list = Mbus::Config.exchange_entries_for_app('discussions')
    validate_exchange_list(list, ["soomo"]) 
    
    list = Mbus::Config.exchange_entries_for_app('cac')
    validate_exchange_list(list, ["logs"])
    
    list = Mbus::Config.exchange_entries_for_app('analytics-consumer')
    validate_exchange_list(list, ["soomo"]) 
    
    list = Mbus::Config.exchange_entries_for_app('logging-consumer')
    validate_exchange_list(list, ["logs"]) 
  end 

  it 'should implement method queues_for_app' do
    Mbus::Config.initialize('rspec_app', @opts)
    Mbus::Config.queues_for_app(nil).should == []
    Mbus::Config.queues_for_app('undefined').should == []

    list = Mbus::Config.queues_for_app('all')
    names = list.collect { | entry | "#{entry['exch']}|#{entry['name']}" }
    expected = ["logs|messages", "soomo|alerts-exception", "soomo|analytics-grade", 
                "soomo|analytics-student", "soomo|blackboard-grade", "soomo|sle-discussion", 
                "soomo|sle-student"]
    names.sort.should == expected
    
    list = Mbus::Config.queues_for_app('core')
    list.size.should == 0

    list = Mbus::Config.queues_for_app('sle')
    list.size.should == 0

    list = Mbus::Config.queues_for_app('sle-consumer')
    names = list.collect { | entry | "#{entry['exch']}|#{entry['name']}" }
    names.sort.should == ["soomo|sle-discussion", "soomo|sle-student"] 
    
    list = Mbus::Config.queues_for_app('logging-consumer')
    names = list.collect { | entry | "#{entry['exch']}|#{entry['name']}" }
    names.sort.should == ["logs|messages"]
  end
  
end
