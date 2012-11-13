#! /usr/bin/env ruby

# Adds project root to load path
$: << File.expand_path("../../../", __FILE__)

require 'lib/soomo-mbus'

# Setup configuration
config_location = ENV['MBUS_HOME'] = "redis://localhost:6379/#MBUS_INTEGRATION_TEST_CONFIG"
config = Mbus::ConfigBuilder.new(default_exchange: 'test').build
Mbus::Config.set_config(config_location, config)

include Mbus::Producer

puts "Started."

Mbus::Io.initialize("test", rabbitmq_url: "amqp://localhost/test")

# should I clear all messages before sending??

ARGV.shift.to_i.times do |n|
	mbus_enqueue({id: n}, "test_message")
	puts "Enqueued message #{n}"
end

puts "Done."
