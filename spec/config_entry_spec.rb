require 'spec_helper'

describe Mbus::ConfigEntry do
  
  it 'should assign nil values from an invalid entry String' do
    entry = Mbus::ConfigEntry.new(nil)
    entry.valid?.should be_false
    entry.exchange.should be_nil
    entry.queue.should be_nil
    entry.bind_key.should be_nil
  end
  
  it 'should assign valid values from a valid entry String' do
    entry = Mbus::ConfigEntry.new('soomo,rake,rake.*') 
    entry.raw_value.should == 'soomo,rake,rake.*'
    entry.valid?.should be_true
    entry.exchange.should == 'soomo'
    entry.queue.should == 'rake'
    entry.bind_key.should == 'rake.*'
    entry.fullname.should == 'soomo|rake'
  end

end
