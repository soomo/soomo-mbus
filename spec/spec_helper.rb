require 'simplecov'
SimpleCov.start do
	add_filter "vendor/bundle"
end

require 'rspec'
require 'bunny'
require 'json'
require 'redis'
require 'uri'
require 'soomo-mbus'

# Note - In these specs, Redis is assumed to be running at URL 'redis://localhost:6379'.

RSpec.configure do | config |
	config.color_enabled = true
	config.formatter     = 'documentation'
end

class TestProducer
	include Mbus::Producer
	def doit(obj, action, custom_json_msg_string=nil)
		mbus_enqueue(obj, action, custom_json_msg_string)
	end
end

class LogMessageMessageHandler < Mbus::BaseMessageHandler
	def handle(msg)
		@message = msg
		if (data = @message['data']) && (e = data['exception'])
			raise(e)
		end
		@message
	end
end

def set_local_redis_config
	result = Mbus::Config.set_config(config_location_local_rspec, test_config_json)
	result.should be_true
end

def config_location_local_rspec
	'redis://localhost:6379/#MBUS_CONFIG_RSPEC'
end

def test_config_json
	@test_config_json ||= File.read File.expand_path('../fixtures/test_config.json', __FILE__)
end

def flush_message_bus
	ENV['MBUS_APP'] = 'logging-consumer'
	opts = {:start_bunny => true, :verbose => false, :silent => true}

	continue_to_process = true
	messages = []

	Mbus::Io.initialize('logging-consumer', opts)
	while continue_to_process
		msg = Mbus::Io.read_message('logs', 'messages')
		if (msg == :queue_empty) || msg.nil?
			continue_to_process = false
		else
			messages << msg.payload
			Mbus::Io.acknowledge_message(msg)
		end

		yield messages.size if block_given?
	end
	Mbus::Io.shutdown

	return messages
end
