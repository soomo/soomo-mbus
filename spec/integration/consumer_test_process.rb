#! /usr/bin/env ruby

# Adds project root to load path
$: << File.expand_path("../../../", __FILE__)

require 'lib/soomo-mbus'

# Setup configuration
config_location = ENV['MBUS_HOME'] = "redis://localhost:6379/#MBUS_INTEGRATION_TEST_CONFIG"
config = Mbus::ConfigBuilder.new(default_exchange: 'soomo').build
Mbus::Config.set_config(config_location, config)

@@delay = ARGV.shift.to_i

class TestMessageMessageHandler
	def initialize(opts={})
	end

	def handle(message_hash)
		if data = message_hash['data']
			$stdout.puts "Received #{data.inspect}"
			$stdout.flush
		end
	end
end

ENV['MBUS_APP'] = 'test-consumer'
ENV['APP_NAME'] = 'test'
ENV['MBUS_QE_TIME'] = 'stop'

consumer_process = Mbus::BaseConsumerProcess.new(rabbitmq_url: "amqp://localhost/test", delay: @@delay)
consumer_process.process_loop

