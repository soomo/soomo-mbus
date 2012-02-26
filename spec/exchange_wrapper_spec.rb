require 'spec_helper'

# rake spec SPEC=spec/exchange_wrapper_spec.rb

describe Mbus::ExchangeWrapper do

  it 'should implement a constructor and accessor methods' do
    entry = {'name' => 'log', 'type' => 'topic', 'persistent' => true,
             'mandatory' => true, 'immediate' => true}
    ew = Mbus::ExchangeWrapper.new(entry)
    ew.name.should == 'log'
    ew.type.should == 'topic' 
    ew.type_symbol.should == :topic
    ew.persistent?.should be_true
    ew.mandatory?.should be_true
    ew.immediate?.should be_true
  end
  
  it 'should implement reasonable default values' do
    entry = {'name' => 'reasonable'}
    ew = Mbus::ExchangeWrapper.new(entry)
    ew.name.should == 'reasonable'
    ew.type.should == 'topic' 
    ew.type_symbol.should == :topic
    ew.persistent?.should be_true
    ew.mandatory?.should be_false
    ew.immediate?.should be_false
  end  
  
end
