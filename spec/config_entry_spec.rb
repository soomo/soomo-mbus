require 'spec_helper'

describe Mbus::ConfigEntry do
  
  it 'should assign an invalid object with nil values from an invalid entry String' do
    entry = Mbus::ConfigEntry.new(nil)
    entry.valid?.should be_false
    entry.exchange.should be_nil
    entry.queue.should be_nil
    entry.bind_key.should be_nil
  end
  
  it 'should assign valid values from a valid entry String' do
    entry = Mbus::ConfigEntry.new('test_exch,test_queue1,produce,test.this.*') 
    entry.raw_value.should == 'test_exch,test_queue1,produce,test.this.*'
    entry.valid?.should be_true
    entry.exchange.should == 'test_exch'
    entry.queue.should == 'test_queue1'
    entry.consume?.should be_false 
    entry.produce?.should be_true
    entry.bind_key.should == 'test.this.*'
    entry.fullname.should == 'test_exch|test_queue1'
    
    entry = Mbus::ConfigEntry.new('test_exch,test_queue1,consume,test.this.*') 
    entry.raw_value.should == 'test_exch,test_queue1,consume,test.this.*'
    entry.valid?.should be_true
    entry.exchange.should == 'test_exch'
    entry.queue.should == 'test_queue1'
    entry.consume?.should be_true 
    entry.produce?.should be_false
    entry.bind_key.should == 'test.this.*'
    entry.fullname.should == 'test_exch|test_queue1'
  end

end
