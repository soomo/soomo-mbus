require 'spec_helper'

# rake spec SPEC=spec/config_builder_spec.rb

describe Mbus::ConfigBuilder do

	it 'should include a given version number' do
		builder  = Mbus::ConfigBuilder.new({:version => '1.0.0', :default_exch => 'soomo'})
		json_str = builder.build
		json_obj = JSON.parse(json_str)
		json_obj['version'].should == '1.0.0'
	end

	it 'should implement the method boolean(value, default_value)' do
		builder = Mbus::ConfigBuilder.new
		builder.boolean(nil, true).should be_true
		builder.boolean(nil, false).should be_false
		builder.boolean('true', true).should be_true
		builder.boolean('false', false).should be_false
		builder.boolean('what?', false).should be_false
	end

	it 'should implement the method valid?(...)' do
		builder = Mbus::ConfigBuilder.new
		builder.valid?('test', {'a' => 'a', 'b' => 'b'}, keys=['a', 'b'], false).should be_true
		builder.valid?('test', {'a' => 'a', 'b' => 'b'}, keys=['a', 'b', 'c'], false).should be_false
	end

end
