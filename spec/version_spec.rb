require 'spec_helper'

# rake spec SPEC=spec/version_spec.rb

describe Mbus do
  
  it 'should return the correct version string' do
    Mbus::VERSION.should == "0.8.0"
  end
  
end
