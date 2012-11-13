#! /usr/bin/env ruby

# Adds project root to load path
$: << File.expand_path("../../../", __FILE__)

require 'lib/soomo-mbus'

# Setup configuration
config_location = ENV['MBUS_HOME'] = "redis://localhost:6379/#MBUS_INTEGRATION_TEST_CONFIG"
config = Mbus::ConfigBuilder.new(default_exchange: 'soomo').build
Mbus::Config.set_config(config_location, config)

@@verbose = (ARGV.shift == "-v")

def verbose?
	@@verbose
end

def execute(command)
	full_command = "rabbitmqctl #{command}"
	puts "Running '#{full_command}'" if verbose?
	output = `#{full_command}`
	display_output(output)
	output
end

def kill_all_rabbit_test_connections!
	output = execute %(list_connections -p test pid)
	output.split("\n")[1..-2].each do |conn_pid|
		puts "Connection PID = #{conn_pid}"
		execute %(close_connection '#{conn_pid}' 'Closed for integration testing purposes.')
	end
end

def restart_rabbitmq(delay=0)
	execute %(stop_app)
	sleep(delay)
	execute %(start_app)
end

def display_output(output)
	padded = ("\n#{output}").gsub(/\n/,"\n    ")
	puts "Output:\n#{padded}\n----\n" if verbose?
end

def setup
	execute %(add_vhost test)
	execute %(set_permissions -p test guest ".*" ".*" ".*")
	puts "\nSetup complete.\n\n" if verbose?
end

def teardown
	execute %(delete_vhost test)
	puts "\nTeardown complete.\n\n" if verbose?
end

def run_test
	begin
		setup
		test
	ensure
		teardown
	end
end

def binpath(kind)
	File.expand_path("../#{kind}_test_process.rb", __FILE__)
end

def test

	max_run_time = Time.now.to_i + 60

	# Ensure queue is created.
	output = `bundle exec #{binpath(:consumer)}`
	display_output(output)

	# Queue up 30 test messages.
	messages_sent = 30
	output = `bundle exec #{binpath(:producer)} #{messages_sent}`
	display_output(output)

	# Read from queue with 1 second delay.
	io = IO.popen("bundle exec #{binpath(:consumer)} 1")
	puts "Consumer PID = #{io.pid}"

	messages_read = 0
	consumer_io_thread = Thread.new do
		io.each do |s|
			puts(s) if s.length > 0
			if s =~ /Received .*/
				messages_read += 1
			end
		end
	end

	sleep(5)
	kill_all_rabbit_test_connections!

	sleep(5)
	restart_rabbitmq

	sleep(5)
	restart_rabbitmq(5) # 5 second outage.

	consumer_io_thread.join

	puts "Read #{messages_read} messages out of #{messages_sent}"
	abort("Integration test failed.") unless messages_read == messages_sent

	puts "Exiting normally."

	# bunny is started in initialize.

	# so, we will set up a thread to send messages, sleeping 1 second between each message.
	# it will send 5 messages, then the connection will be closed externally.
	# it should reconnect where it left off.

	# a later test will drop the vhost meaning that the re-connection will be unable to occur.
	# 10 seconds later, the vhost will be brought back up.
	# we expect the messages to begin sending again.

end

run_test

