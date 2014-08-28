require 'spec_helper'

# rake spec SPEC=spec/base_consumer_process_spec.rb

describe Mbus::BaseConsumerProcess do

	before(:each) do
		set_local_redis_config
		ENV['MBUS_APP']      = nil
		ENV['MBUS_HOME']     = config_location_local_rspec
		ENV['MBUS_QE_TIME']  = nil
		ENV['MBUS_MAX_SLEEPS'] = nil
		@opts = {:test_mode => true, :start_bunny => false, :silent => true}
		Mbus::Io.shutdown # ensure we're not running
	end

	it 'should determine its name from environment variable MBUS_APP' do
		ENV['MBUS_APP'] = 'test_app'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.app_name.should == 'test_app'
		process.shutdown

		ENV['MBUS_APP'] = nil
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.app_name.should be_nil
		process.shutdown
	end

	it 'should determine its queue_empty_sleep_time from environment variable MBUS_QE_TIME' do
		ENV['MBUS_APP'] = 'test_app'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.queue_empty_sleep_time.should == 15
		process.shutdown

		ENV['MBUS_QE_TIME'] = '16'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.queue_empty_sleep_time.should == 16
		process.shutdown
	end

	it 'should determine its max_sleeps count from environment variable MBUS_MAX_SLEEPS' do
		ENV['MBUS_APP'] = 'test_app'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.max_sleeps.should == -1
		process.shutdown

		ENV['MBUS_MAX_SLEEPS'] = '3'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.max_sleeps.should == 3
		process.shutdown
	end


	it 'should determine its queues from the configuration at MBUS_HOME' do
		ENV['MBUS_APP'] = 'logging-consumer'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.app_name.should == 'logging-consumer'
		qnames = process.queues_list.collect { | qw | qw.fullname }
		process.continue_to_process.should be_true
		qnames.should == ["logs|messages"]
		process.shutdown

		ENV['MBUS_APP'] = nil
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.app_name.should be_nil
		qnames = process.queues_list.collect { | qw | qw.fullname }
		process.continue_to_process.should be_false
		qnames.should == []
		process.shutdown

		ENV['MBUS_APP'] = 'undefined-consumer'
		process = Mbus::BaseConsumerProcess.new(@opts)
		process.app_name.should == 'undefined-consumer'
		qnames = process.queues_list.collect { | qw | qw.fullname }
		process.continue_to_process.should be_false
		qnames.should == []
		process.shutdown
	end

	it 'should implement its standard methods' do
		ENV['MBUS_APP'] = 'test_app'
		process = Mbus::BaseConsumerProcess.new({:test_mode => false, :start_bunny => false, :silent => true})
		process.app_name.should == 'test_app'
		process.shutdown
	end

	it 'should implement method classname_from_action' do
		ENV['MBUS_APP'] = 'test_app'
		process = Mbus::BaseConsumerProcess.new(@opts)

		process.classname_map.size.should == 0
		cn = process.classname_from_action('some_action')
		cn.should == 'SomeActionMessageHandler'
		process.classname_map.size.should == 1
		process.classname_map['some_action'].should == 'SomeActionMessageHandler'

		cn = process.classname_from_action('awesome_possum')
		cn.should == 'AwesomePossumMessageHandler'
		process.classname_map.size.should == 2
		process.classname_map['awesome_possum'].should == 'AwesomePossumMessageHandler'

		cn = process.classname_from_action('awesome-possum')
		cn.should == 'AwesomePossumMessageHandler'
		process.classname_map.size.should == 3
		process.classname_map['awesome-possum'].should == 'AwesomePossumMessageHandler'

		process.shutdown
	end

	it 'should execute its run loop with no sleeps' do
		# First, drain the queue of messages.
		flush_message_bus

		# Next, send some new log messages
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', {:verbose => false, :silent => true})
		tp = TestProducer.new
		13.times do | i |
			data = {:n => i, :epoch => Time.now.to_i}
			# produce messages for which will be handled in BaseConsumerProcess by
			# instances of class LogMessageMessageHandler
			msg  = tp.doit(data, 'log_message')
			msg  = tp.doit("String message #{i} at #{Time.now.to_i}", 'log_message')
		end
		Mbus::Io.shutdown

		# Run the consumer to process the new messages
		ENV['MBUS_APP'] = 'logging-consumer'
		ENV['MBUS_QE_TIME'] = 'stop'
		process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
		process.process_loop
		process.messages_read.should == 26
		process.messages_processed.should == 26
		process.max_sleeps.should  == -1
		process.sleep_count.should == 0

		# Run the consumer again, there should be no messages
		ENV['MBUS_APP'] = 'logging-consumer'
		ENV['MBUS_QE_TIME'] = 'stop'
		process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
		process.process_loop
		process.messages_read.should == 0
		process.messages_read.should == 0
	end

	it "should execute its run process with at least 1 sleep" do
		# First, drain the queue of messages.
		flush_message_bus

		# Run the consumer
		ENV['MBUS_APP'] = 'logging-consumer'
		ENV['MBUS_QE_TIME'] = '1'
		ENV['MBUS_MAX_SLEEPS'] = '2'
		process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
		process.process_loop
		process.max_sleeps.should  == 2
		process.sleep_count.should == 2
	end

	it "should trap INT and TERM signals." do
		ENV['MBUS_APP'] = 'logging-consumer'
		ENV['MBUS_QE_TIME'] = '1'

		run_process = Proc.new do
			fork do
				process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
				process.process_loop
				exit!(99)
			end
		end

		%w(INT TERM).each do |signal|
			pid = run_process.call
			puts "Started child process with PID = #{pid}"
			sleep(1) # ensure things are started.
			Process.kill(signal, pid)
			Process.wait
			$?.exitstatus.should == 99
		end
	end

	it "should exit with code = 1 if failure and ACK required" do

		# put an exceptional message into the queue.
		ENV['MBUS_APP'] = 'core'
		Mbus::Io.initialize('core', verbose: false, silent: true)
		producer = TestProducer.new
		_message = producer.doit({ exception: 'boom' }, 'log_message')
		Mbus::Io.shutdown

		# read off the exceptional message
		pid = fork do
			ENV['MBUS_APP'] = 'logging-consumer'
			ENV['MBUS_QE_TIME'] = '1'
			process = Mbus::BaseConsumerProcess.new(verbose: false, silent: true)
			process.process_loop
		end
		puts "Started child process with PID = #{pid}"
		Process.wait(pid)

		# the exceptional message should result in a non-success exit status
		$?.exitstatus.should == 1
	end

end
