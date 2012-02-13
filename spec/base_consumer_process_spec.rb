require 'spec_helper'

describe Mbus::BaseConsumerProcess do
  
  it 'should return nil from default_exchange' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.default_exchange.should be_nil
  end 
  
  it 'should return nil from default_queue' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.default_queue.should be_nil
  end 
  
  it 'should return the default value from init_queue_empty_sleep_time' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.init_queue_empty_sleep_time.should == 10
  end
  
  it 'should return -1 from init_queue_empty_sleep_time per environment variable' do
    ENV['SLEEP_TIME'] = 'stop' 
    process = Mbus::BaseConsumerProcess.new(true)
    process.init_queue_empty_sleep_time.should == -1
  end  
  
  it 'should return the default value from init_db_disconnected_sleep_time' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.init_db_disconnected_sleep_time.should == 15
  end 
  
  it 'should implement the method "classname"' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.classname.should == 'Mbus::BaseConsumerProcess'
  end 
  
  it 'should implement the method "to_bool"' do
    process = Mbus::BaseConsumerProcess.new(true)
    process.to_bool("true").should be_true 
    process.to_bool("TRUE").should be_true
    process.to_bool("false").should be_false 
    process.to_bool("0").should be_false
    process.to_bool("1").should be_false
    process.to_bool("t").should be_false
  end
  
  it 'should implement the method "database_url"' do 
    ENV['DB'] = nil 
    ENV['DATABASE_URL'] = nil
    process = Mbus::BaseConsumerProcess.new(true)
    process.database_url.should be_nil

    ENV['DB'] = nil 
    ENV['DATABASE_URL'] = 'postgres://...'
    process = Mbus::BaseConsumerProcess.new(true)
    process.database_url.should == 'postgres://...'

    ENV['DB'] = 'OTHER_DATABASE_URL'
    ENV['DATABASE_URL'] = 'postgres://...'   
    ENV['OTHER_DATABASE_URL'] = 'postgres://other...'
    process = Mbus::BaseConsumerProcess.new(true)
    process.database_url.should == 'postgres://other...'
  end 
  
  it 'should implement the method "use_database?"' do 
    ENV['DATABASE_URL'] = 'postgres://...'
    process = Mbus::BaseConsumerProcess.new(true)
    process.use_database?.should be_true

    ENV['DB'] = 'NO_DATABASE_URL'
    ENV['DATABASE_URL'] = 'postgres://...'   
    ENV['NO_DATABASE_URL'] = 'none'
    process = Mbus::BaseConsumerProcess.new(true)
    process.use_database?.should be_false 
  end

end
  