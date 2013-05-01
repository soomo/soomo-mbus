require 'spec_helper'

# rake spec SPEC=spec/producer_spec.rb

describe Mbus::Producer do

	include Mbus::Producer

	before(:all) do
		ENV['RABBITMQ_URL'] = 'amqp://localhost'
		opts = {:verbose => false, :silent => true}
		Mbus::Io.initialize('core', opts)
	end

	after(:all) do
		Mbus::Io.shutdown
	end

	it 'should implement method build_message' do
		tp = TestProducer.new
		data = {:group => "Salt-N-Pepa", :song => "Push It"}
		json_str = tp.build_message('core', {}, 'some_action', 'soomo', 'a.b.c', data)
		json_obj = JSON.parse(json_str)
		json_obj['app'].should    == 'core'
		json_obj['object'].should == 'Hash'
		json_obj['action'].should == 'some_action'
		json_obj['rkey'].should   == 'a.b.c'
		epoch =Time.now.to_i
		json_obj['sent_at'].should > epoch - 2
		json_obj['sent_at'].should < epoch + 2
		json_obj['data']['song'].should == 'Push It'
	end

	it 'should not send an undefined message' do
		tp = TestProducer.new
		json_str = tp.doit([], 'message') # Array undefined in config
		json_str.should be_nil
	end

	it 'should successfully send an auto-formatted message' do
		tp = TestProducer.new
		json_str = tp.doit({}, 'log_message')
		json_str.should_not be_nil
		json_obj = JSON.parse(json_str)
		#puts JSON.pretty_generate(json_obj)
		json_obj['app'].should    == 'core'
		json_obj['object'].should == 'Hash'
		json_obj['action'].should == 'log_message'
		json_obj['rkey'].should   == 'logs.app-core.object-hash.action-log_message'
		epoch =Time.now.to_i
		json_obj['sent_at'].should > epoch - 2
		json_obj['sent_at'].should < epoch + 2
	end

	it 'should successfully send a manually-formatted message' do
		custom_msg = {'location' => 'miami', 'count' => 2}
		tp = TestProducer.new
		json_str = tp.doit({}, 'log_message', custom_msg.to_json)
		json_str.should_not be_nil
		json_obj = JSON.parse(json_str)
		#puts JSON.pretty_generate(json_obj)
		json_obj['app'].should    == 'core'
		json_obj['object'].should == 'Hash'
		json_obj['action'].should == 'log_message'
		json_obj['data'].include?('miami').should be_true
		json_obj['rkey'].should   == 'logs.app-core.object-hash.action-log_message'
		epoch =Time.now.to_i
		json_obj['sent_at'].should > epoch - 2
		json_obj['sent_at'].should < epoch + 2
	end

	it 'should add mbus_enqueue method to Mbus module and alias to .enqueue' do
		Mbus.should respond_to :enqueue
	end

end
