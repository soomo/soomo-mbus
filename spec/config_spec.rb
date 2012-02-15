require 'spec_helper'

describe Mbus::Config do
  
  before(:each) do
    ENV['MBUS_ENV'] = nil
  end
  
  it 'should have the correct DEFAULT_CONFIG_ENV_VAR value' do 
    Mbus::Config.initialize
    Mbus::Config::DEFAULT_CONFIG_ENV_VAR.should == 'MBUS_CONFIG_DEFAULT'
  end 
  
  it 'should have the correct default config_env_var_name value' do 
    Mbus::Config.initialize
    Mbus::Config::config_env_var_name.should == 'MBUS_CONFIG_DEFAULT'
  end
  
  it 'should have the correct overridden config_env_var_name value' do
    process_specific_variable = 'MBUS_CONFIG_RSPEC_TEST'
    process_specific_config   = 'rspec,test,consume,test.*'
    ENV[process_specific_variable] = process_specific_config 
    ENV[default_config_env_var] = standard_config_value 
    ENV['MBUS_ENV'] = process_specific_variable 
    Mbus::Config.initialize
    Mbus::Config::config_env_var_name.should == 'MBUS_CONFIG_RSPEC_TEST'
  end 
  
  it 'should implement the entry_delimiter method' do
    Mbus::Config.initialize 
    Mbus::Config.entry_delimiter.should == '/'
  end
  
  it 'should implement the entry_field_delimiter method' do
    Mbus::Config.initialize 
    Mbus::Config.entry_field_delimiter.should == ','
  end  
  
  it 'should return the default rabbitmq_url' do
    ENV['RABBITMQ_URL'] = nil
    Mbus::Config.initialize 
    Mbus::Config.rabbitmq_url.should == 'amqp://localhost'
  end
  
  it 'should return a rabbitmq_url per the environment variable' do
    url = 'amqp://1.2.3.4:5678'
    ENV['RABBITMQ_URL'] = url
    Mbus::Config.initialize  
    Mbus::Config.rabbitmq_url.should == url
  end 
  
  it 'should return an overridden rabbitmq_url' do
    ENV['RABBITMQ_URL'] = nil
    opts = {:rabbitmq_url => 'amqps://somehost'} 
    Mbus::Config.initialize(opts) 
    Mbus::Config.rabbitmq_url.should == 'amqps://somehost'
  end
  
  it 'should return the default exchanges' do
    ENV[default_config_env_var] = nil
    Mbus::Config.initialize  
    Mbus::Config.exchanges.size.should == 0
  end

  it 'should implement the initialize_exchanges? method' do
    Mbus::Config.initialize 
    Mbus::Config.initialize_exchanges?.should be_true

    opts = {:initialize_exchanges => 'maybe'} 
    Mbus::Config.initialize(opts)
    Mbus::Config.initialize_exchanges?.should be_true 
    
    opts = {:initialize_exchanges => 'false'} 
    Mbus::Config.initialize(opts) 
    Mbus::Config.initialize_exchanges?.should be_false 
    
    opts = {:initialize_exchanges => 'false', :action => 'status'} 
    Mbus::Config.initialize(opts) 
    Mbus::Config.initialize_exchanges?.should be_true 
  end
  
  it 'should implement the is_consumer? method' do
    ENV[default_config_env_var] = standard_config_value
    Mbus::Config.initialize 
    Mbus::Config.is_consumer?('vendor1_exch').should be_true
    Mbus::Config.is_consumer?('test_exch').should be_false 
  end
  
  it 'should implement the is_consumer? method, with options' do
    ENV[default_config_env_var] = standard_config_value
    opts = {:action => 'status'} 
    Mbus::Config.initialize(opts) 
    Mbus::Config.is_consumer?('vendor1_exch').should be_true
    Mbus::Config.is_consumer?('test_exch').should be_true 
  end 
  
  it 'should return the default config_value value' do 
    ENV[default_config_env_var] = standard_config_value
    Mbus::Config.initialize  
    Mbus::Config.config_value.should == standard_config_value
    ENV['MBUS_ENV'] = 'NON_EXISTANT_ENVIRONMENT_VARIABLE'
    Mbus::Config.initialize
    Mbus::Config.config_value.should == standard_config_value
  end
  
  it 'should return a process-specific config_value value' do
    process_specific_variable = 'MBUS_CONFIG_RSPEC_TEST'
    process_specific_config   = 'rspec,test,consume,test.*'
    ENV[process_specific_variable] = process_specific_config
    ENV[default_config_env_var] = standard_config_value 
    ENV['MBUS_ENV'] = process_specific_variable 
    Mbus::Config.initialize
    Mbus::Config.config_value.should == process_specific_config
  end
  
  it 'should implement methods consumer_exchange and consumer_queue' do 
    process_specific_variable = 'MBUS_CONFIG_RSPEC_TEST'
    process_specific_config   = 'rspec2,test2,consume,test.*'
    ENV[process_specific_variable] = process_specific_config 
    ENV[default_config_env_var] = standard_config_value 
    ENV['MBUS_ENV'] = process_specific_variable
    Mbus::Config.initialize  
    Mbus::Config.consumer_exchange.should == 'rspec2'
    Mbus::Config.consumer_queue.should == 'test2' 
  end 
  
  it 'should return the exchanges per the default environment variable' do
    ENV[default_config_env_var] = standard_config_value
    Mbus::Config.initialize 
    Mbus::Config.exchanges.size.should == 3
    Mbus::Config.exchanges.include?('test_exch').should be_true
    Mbus::Config.exchanges.include?('vendor1_exch').should be_true
    Mbus::Config.exchanges.include?('vendor2_exch').should be_true 
  end 
  
  it 'should return the exchanges per a process-specific environment variable' do
    process_specific_variable = 'MBUS_CONFIG_RSPEC_TEST'
    process_specific_config   = 'rspec,test,produce,test.*'
    ENV[process_specific_variable] = process_specific_config 
    ENV[default_config_env_var] = standard_config_value
    ENV['MBUS_ENV'] = process_specific_variable
    Mbus::Config.initialize 
    Mbus::Config.exchanges.size.should == 1
    Mbus::Config.exchanges.include?('rspec').should be_true
    Mbus::Config.exchanges.include?('test_exch').should be_false
  end 
  
  it 'should return the default exch_entries' do
    ENV[default_config_env_var] = nil 
    Mbus::Config.initialize 
    Mbus::Config.exch_entries(nil).size.should == 0 
    Mbus::Config.exch_entries('soomo').size.should == 0 
    Mbus::Config.exch_entries('blackboard').size.should == 0
  end
  
  it 'should return the exch_entries per the environment variable' do
    ENV[default_config_env_var] = standard_config_value
    Mbus::Config.initialize 
    Mbus::Config.exch_entries(nil).size.should == 0 
    entries = Mbus::Config.exch_entries('test_exch')
    entries.size.should == 2
    entries[0].raw_value.should == 'test_exch,test_queue1,produce,test.this.*' 
    entries[1].raw_value.should == 'test_exch,test_queue2,produce,test.that.*'
    entries = Mbus::Config.exch_entries('vendor1_exch')
    entries.size.should == 1 
    entries[0].raw_value.should == 'vendor1_exch,vendor1_queue,consume,vendor1.*' 
  end
  
end
