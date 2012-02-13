require 'spec_helper'

describe Mbus do
  
  it 'should return the correct version string' do
    Mbus::VERSION.should == "0.5.3"
  end
  
end
