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

def default_config_env_var
	Mbus::Config::DEFAULT_CONFIG_ENV_VAR
end

def test_app_name
	'rspec_app'
end

def test_config_locations
	"#{config_location_local_rspec}^#{config_location_local_not_there}"
end

def config_location_local_rspec
	'redis://localhost:6379/#MBUS_CONFIG_RSPEC'
end

def config_location_local_not_there
	'redis://localhost:6379/#MBUS_CONFIG_NOT_THERE'
end

def set_local_redis_config
	result = Mbus::Config.set_config(config_location_local_rspec, test_config_json)
	result.should be_true
end

def test_config_json
	@test_config_json ||= File.read File.expand_path('../fixtures/test_config.json', __FILE__)
end
