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
		Mbus::Io.classname.should == 'Mbus::Io'
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
		Mbus::Io.start_bunny?.should be_false
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
		Mbus::Io.exchanges.should_not be_nil
		Mbus::Io.exchanges.size.should == 2

		ew = Mbus::Io.exchanges['logs']
		ew.should_not be_nil
		ew.exchange.should_not be_nil

		ew = Mbus::Io.exchanges['soomo']
		ew.should_not be_nil
		ew.exchange.should_not be_nil
		ew.persistent?.should be_true

		# TODO
		# Mbus::Io.queues.should_not be_nil
		# Mbus::Io.queues.size.should == 0
	end

	it 'consumer apps should have exchanges and queues' do
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		Mbus::Io.exchanges.should_not be_nil
		Mbus::Io.exchanges.size.should == 2

		ew = Mbus::Io.exchanges['logs']
		ew.should_not be_nil
		ew.exchange.should_not be_nil

		ew = Mbus::Io.exchanges['soomo']
		ew.should_not be_nil
		ew.exchange.should_not be_nil
		ew.persistent?.should be_true

		Mbus::Io.queues.should_not be_nil
		Mbus::Io.queues.size.should == 1
		qw = Mbus::Io.queues['logs|messages']
		qw.should_not be_nil
		qw.exch.should == 'logs'
		qw.name.should == 'messages'
		qw.queue.should_not be_nil
	end

	it 'should implement method fullname' do
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		Mbus::Io.fullname('exch', 'queue92').should == 'exch|queue92'
	end

	it 'should implement method delete_exchange' do
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', @opts)
		Mbus::Io.delete_exchange('undefined', {}).should be_nil
		Mbus::Io.delete_exchange('logs', {}).should == :delete_ok
		Mbus::Io.delete_exchange('soomo', {}).should == :delete_ok
	end

	it 'should implement method status' do
		ENV['MBUS_APP'] = 'all'
		Mbus::Io.initialize('all', @opts)
		hash = Mbus::Io.status
		hash.should_not be_nil
		hash.size.should == 5
		hash['logs|messages'].should_not be_nil
		hash.keys.sort.each_with_index { | key, idx |
			val = hash[key]
			val.has_key?(:message_count).should be_true
			val.has_key?(:consumer_count).should be_true
		}
	end

	it 'should send messages, read messages, and ack messages' do
		# First, drain the queue of messages.
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		continue_to_process = true
		while continue_to_process
			msg = Mbus::Io.read_message('logs', 'messages')
			if (msg == :queue_empty) || msg.nil?
				continue_to_process = false
			else
				Mbus::Io.ack_queue('logs', 'messages')
			end
		end
		Mbus::Io.shutdown

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
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		continue_to_process, messages = true, []
		while continue_to_process
			msg = Mbus::Io.read_message('logs', 'messages')
			if (msg == :queue_empty) || msg.nil?
				continue_to_process = false
			else
				messages << msg
				Mbus::Io.ack_queue('logs', 'messages')
			end
		end
		Mbus::Io.shutdown
		messages.size.should == 3
		messages[0].should == msg1
		messages[1].should == msg2
		messages[2].should == msg3

		# Next, read again, there should be no more messages.
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		continue_to_process, messages = true, []
		while continue_to_process
			msg = Mbus::Io.read_message('logs', 'messages')
			if (msg == :queue_empty) || msg.nil?
				continue_to_process = false
			else
				messages << msg
				Mbus::Io.ack_queue('logs', 'messages')
			end
		end
		Mbus::Io.shutdown
		messages.size.should == 0
	end

	it "should handle a disconnect when reading from a queue" do
		# Flush message bus.
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		continue_to_process = true
		while continue_to_process
			msg = Mbus::Io.read_message('logs', 'messages')
			if (msg == :queue_empty) || msg.nil?
				continue_to_process = false
			else
				Mbus::Io.ack_queue('logs', 'messages')
			end
		end
		Mbus::Io.shutdown

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
		ENV['MBUS_APP'] = 'logging-consumer'
		Mbus::Io.initialize('logging-consumer', @opts)
		continue_to_process = true

		messages_read = 0
		while continue_to_process
			msg = Mbus::Io.read_message('logs', 'messages')

			if (msg == :queue_empty) || msg.nil?
				continue_to_process = false
			else
				messages_read += 1
				Mbus::Io.ack_queue('logs', 'messages')
			end

			if messages_read == 1
				Mbus::Io.shutdown # stops bunny which should yield connection error
			end
		end
		Mbus::Io.shutdown

		messages_read.should == 3
	end

end
