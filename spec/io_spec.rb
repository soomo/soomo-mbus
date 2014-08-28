require 'spec_helper'

# rake spec SPEC=spec/io_spec.rb

describe Mbus::Io do

	before(:all) do
		set_local_redis_config
	end

	before(:each) do
		ENV['RABBITMQ_URL'] = 'amqp://localhost'
		@opts = {:start_bunny => true, :verbose => false, :silent => true}
	end

	after(:all) do
		ENV['RABBITMQ_URL'] = 'amqp://localhost'
		set_local_redis_config
	end

	after(:each) do
		Mbus::Io.shutdown
	end

	it 'should implement method app_name' do
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.send(:app_name).should == 'core'
		Mbus::Config.app_name.should == 'core'

		ENV['MBUS_APP'] = nil
		Mbus::Io.initialize(nil, @opts)
		Mbus::Io.send(:app_name).should be_nil
	end

	it 'should implement method classname' do
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.send(:classname).should == 'Mbus::Io'
	end

	it 'should implement method log_prefix' do
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.send(:log_prefix).should == 'core Mbus::Io'
	end

	it 'should implement method verbose?' do
		Mbus::Io.initialize('core', {:start_bunny => false, :silent => true})
		Mbus::Io.send(:verbose?).should be_false

		Mbus::Io.initialize('core', {:start_bunny => false, :verbose => false, :silent => true})
		Mbus::Io.send(:verbose?).should be_false

		Mbus::Io.initialize('core', {:start_bunny => false, :verbose => true, :silent => true})
		Mbus::Io.send(:verbose?).should be_true
	end

	it 'should implement method silent?' do
		Mbus::Io.initialize('core', {:silent => true, :start_bunny => false})
		Mbus::Io.send(:silent?).should be_true
	end

	it 'should implement method start_bunny?' do
		Mbus::Io.initialize('core', {:start_bunny => false, :silent => true})
		Mbus::Io.send(:start_bunny?).should be_false
	end

	it 'should handle erroneous multiple start method calls' do
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.start.should be_true
		Mbus::Io.start.should be_true
	end

	it 'should handle not start if pointing to a bad RABBITMQ_URL' do
		ENV['RABBITMQ_URL'] = 'amqp://xxx'
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.start.should be_false
		Mbus::Io.start.should be_false
	end

	it 'producer apps should have exchanges but no queues' do
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', @opts)

		exchanges = Mbus::Io.send(:exchanges)
		exchanges.should_not be_nil
		exchanges.size.should == 2

		ew = exchanges['logs']
		ew.should_not be_nil
		ew.exchange.should_not be_nil

		ew = exchanges['soomo']
		ew.should_not be_nil
		ew.exchange.should_not be_nil
		ew.persistent?.should be_true

		# TODO
		#queues = Mbus::Io.send(:queues)
		#queues.should_not be_nil
		#queues.size.should == 0
	end

	it 'consumer apps should have exchanges and queues' do
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)

		exchanges = Mbus::Io.send(:exchanges)
		exchanges.should_not be_nil
		exchanges.size.should == 2

		ew = exchanges['logs']
		ew.should_not be_nil
		ew.exchange.should_not be_nil

		ew = exchanges['soomo']
		ew.should_not be_nil
		ew.exchange.should_not be_nil
		ew.persistent?.should be_true

		queues = Mbus::Io.send(:queues)
		queues.should_not be_nil
		queues.size.should == 1
		qw = queues['logs|messages']
		qw.should_not be_nil
		qw.exch.should == 'logs'
		qw.name.should == 'messages'
		qw.queue.should_not be_nil
	end

	it 'should implement method fullname' do
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		Mbus::Io.send(:fullname, 'exch', 'queue92').should == 'exch|queue92'
	end

	it 'should send messages, read messages, and ack messages' do
		flush_message_bus

		# Next, send some new log messages
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', @opts)
		msg1 = {:n => 1, :io_spec => true, :epoch => Time.now.to_i}.to_json
		msg2 = {:n => 2, :io_spec => true, :epoch => Time.now.to_i}.to_json
		msg3 = "3|true|#{Time.now.to_i}".to_json
		Mbus::Io.send_message('logs', msg1, 'logs.app-core.object-hash.action-log_message')
		Mbus::Io.send_message('logs', msg2, 'logs.app-core.object-hash.action-log_message')
		Mbus::Io.send_message('logs', msg3, 'logs.app-core.object-string.action-log_message')
		Mbus::Io.shutdown

		# Next, read and verify the new messages.
		messages = flush_message_bus
		messages.size.should == 3
		messages[0].should == msg1
		messages[1].should == msg2
		messages[2].should == msg3

		# Next, read again, there should be no more messages.
		messages = flush_message_bus
		messages.size.should == 0
	end

	it "should handle a disconnect when reading from a queue" do
		flush_message_bus

		# Next, send some new log messages
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', @opts)
		msg1 = {:n => 1, :io_spec => true, :epoch => Time.now.to_i}.to_json
		msg2 = {:n => 2, :io_spec => true, :epoch => Time.now.to_i}.to_json
		msg3 = "3|true|#{Time.now.to_i}".to_json
		Mbus::Io.send_message('logs', msg1, 'logs.app-core.object-hash.action-log_message')
		Mbus::Io.send_message('logs', msg2, 'logs.app-core.object-hash.action-log_message')
		Mbus::Io.send_message('logs', msg3, 'logs.app-core.object-string.action-log_message')
		Mbus::Io.shutdown

		# Now, read some messages, disconnecting partway through.
		messages = flush_message_bus do |messages_read|
			if messages_read == 1
				Mbus::Io.shutdown # stops bunny which should yield connection error
			end
		end
		messages.size.should == 3
	end

end
