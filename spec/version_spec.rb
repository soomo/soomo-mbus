require 'spec_helper'

describe Mbus do
  
  it 'should return correct version string' do
    Mbus::VERSION.should == "0.2.0"
  end
  
end
