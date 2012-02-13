require 'spec_helper'

describe Mbus::Config do

  it 'should implement the method entry_delimiter' do
    ENV['RABBITMQ_URL'] = nil
    Mbus::Config.entry_delimiter.should == '/'
  end
  
  it 'should implement the method entry_field_delimiter' do
    ENV['RABBITMQ_URL'] = nil
    Mbus::Config.entry_field_delimiter.should == ','
  end  
  
  it 'should return the default rabbitmq_url' do
    ENV['RABBITMQ_URL'] = nil
    Mbus::Config.rabbitmq_url.should == 'amqp://localhost'
  end
  
  it 'should return a rabbitmq_url per the environment variable' do
    url = 'amqp://1.2.3.4:5678'
    ENV['RABBITMQ_URL'] = url 
    Mbus::Config.rabbitmq_url.should == url
  end
  
  it 'should return the default exchanges' do
    ENV['MBUS_CONFIG'] = nil 
    Mbus::Config.exchanges.size.should == 1
    Mbus::Config.exchanges[0].should == 'soomo'
  end
  
  it 'should return the exchanges per the environment variable' do
    ENV['MBUS_CONFIG'] = standard_mbus_config
    Mbus::Config.exchanges.size.should == 3
    Mbus::Config.exchanges.include?('soomo').should be_true
    Mbus::Config.exchanges.include?('blackboard').should be_true
    Mbus::Config.exchanges.include?('customers').should be_true
  end
  
  it 'should return the default exch_entries' do
    ENV['MBUS_CONFIG'] = nil
    Mbus::Config.exch_entries(nil).size.should == 0 
    Mbus::Config.exch_entries('soomo').size.should == 0 
    Mbus::Config.exch_entries('blackboard').size.should == 0
  end
  
  it 'should return the exch_entries per the environment variable' do
    ENV['MBUS_CONFIG'] = standard_mbus_config
    Mbus::Config.exch_entries(nil).size.should == 0 
    entries = Mbus::Config.exch_entries('soomo')
    entries.size.should == 5
    entries[0].raw_value.should == 'soomo,rake,rake.*' 
    entries[1].raw_value.should == 'soomo,activity,activity.*'
    entries = Mbus::Config.exch_entries('blackboard')
    entries.size.should == 1 
    entries[0].raw_value.should == 'blackboard,push,grade.*' 
  end
  
end
