require 'spec_helper'

describe Mbus::BaseConsumerProcess do
  before(:each) do
    ENV['DATABASE_URL'] = 'none'
    @opts = {:test_mode => true}
  end

  it 'should return its exchange and queue names from the default ' do
    ENV[default_config_env_var] = standard_config_value   

    process = Mbus::BaseConsumerProcess.new(@opts)
    process.exchange_name.should == 'test_exch'
    process.queue_name.should == 'test_queue1'
  end
  
  it 'should return its exchange and queue names' do
    process_specific_variable = 'MBUS_CONFIG_TEST'
    process_specific_config   = 'rspec3,test3,consume,test.*'
    ENV[process_specific_variable] = process_specific_config 
    ENV[default_config_env_var] = standard_config_value   
    ENV['MBUS_ENV'] = process_specific_variable
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.exchange_name.should == 'rspec3'
    process.queue_name.should == 'test3'
  end 
  
  it 'should return the default value from init_queue_empty_sleep_time' do 
    opts = {:test_mode => true} 
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.init_queue_empty_sleep_time.should == 10
  end
  
  it 'should return -1 from init_queue_empty_sleep_time per environment variable' do
    opts = {:test_mode => true}
    ENV['MBUS_QE_TIME'] = 'stop' 
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.init_queue_empty_sleep_time.should == -1
  end  
  
  it 'should return the default value from init_db_disconnected_sleep_time' do 
    opts = {:test_mode => true} 
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.init_db_disconnected_sleep_time.should == 15
  end
  
  it 'should return the value from init_db_disconnected_sleep_time per environment variable value' do 
    opts = {:test_mode => true}
    ENV['MBUS_DBC_TIME'] = '23'  
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.init_db_disconnected_sleep_time.should == 23
  end    
  
  it 'should implement the method "classname"' do
    opts = {:test_mode => true} 
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.classname.should == 'Mbus::BaseConsumerProcess'
  end 
  
  it 'should implement the method "to_bool"' do
    opts = {:test_mode => true} 
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.to_bool("true").should be_true 
    process.to_bool("TRUE").should be_true
    process.to_bool("false").should be_false 
    process.to_bool("0").should be_false
    process.to_bool("1").should be_false
    process.to_bool("t").should be_false
  end
  
  it 'should implement the method "database_url"' do 
    opts = {:test_mode => true} 

    ENV['MBUS_DB'] = nil 
    ENV['DATABASE_URL'] = 'postgres://localhost'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.database_url.should == 'postgres://localhost'

    ENV['MBUS_DB'] = 'OTHER_DATABASE_URL'
    ENV['DATABASE_URL'] = 'postgres://...'   
    ENV['OTHER_DATABASE_URL'] = 'postgres://other...'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.database_url.should == 'postgres://other...'
  end 
  
  it 'should implement the method "use_database?"' do
    opts = {:test_mode => true}  
    ENV['DATABASE_URL'] = 'postgres://...'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.use_database?.should be_true

    ENV['MBUS_DB'] = 'NO_DATABASE_URL'
    ENV['DATABASE_URL'] = 'postgres://...'   
    ENV['NO_DATABASE_URL'] = 'none'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.use_database?.should be_false 
  end

end
  