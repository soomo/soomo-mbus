require 'simplecov'
SimpleCov.start

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

def validate_exchange_list(hashes_list, expected_exch_names)
	hashes_list.size.should == expected_exch_names.size
	actual_names = hashes_list.collect { | entry | entry['name'] }
	expected_exch_names.sort.should == actual_names.sort
end

def validate_config_object(json_obj, result, expected_errors, format_errors=false)
	validator = Mbus::ConfigValidator.new(json_obj)
	validator.valid?.should == result
	if format_errors
		sio = StringIO.new
		sio << '['
		validator.errors.each { | err | sio << "\"#{err}\",\n" }
		sio << ']'
		puts sio.string
	end
	validator.errors.size.should == expected_errors.size
	validator.errors.should == expected_errors
end

def test_config_json
	template = <<HEREDOC
{
	"version": "2012-03-02 09:48:51 -0500",
	"exchanges": [
		{
			"name": "soomo",
			"type": "topic",
			"persistent": true,
			"mandatory": false,
			"immediate": false
		},
		{
			"name": "logs",
			"persistent": true,
			"type": "topic",
			"mandatory": false,
			"immediate": false
		}
	],
	"queues": [
		{
			"name": "student_responses",
			"key": "#.action-response_broadcast",
			"exch": "soomo",
			"durable": true,
			"ack": true
		},
		{
			"name": "blackboard-grade",
			"key": "#.action-grade_broadcast",
			"exch": "soomo",
			"durable": true,
			"ack": true
		},
		{
			"name": "sle-student",
			"key": "#.object-student.#",
			"exch": "soomo",
			"durable": true,
			"ack": true
		},
		{
			"name": "sle-discussion",
			"key": "#.object-discussion.#",
			"exch": "soomo",
			"durable": true,
			"ack": true
		},
		{
			"exch": "logs",
			"name": "messages",
			"ack": true,
			"key": "#.action-log_message",
			"durable": true
		}
	],
	"business_functions": [
		{
			"app": "core",
			"object": "grade",
			"action": "grade_create",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-grade.action-grade_create"
		},
		{
			"app": "core",
			"object": "grade",
			"action": "grade_update",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-grade.action-grade_update"
		},
		{
			"app": "core",
			"object": "grade",
			"action": "grade_exception",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-grade.action-grade_exception"
		},
		{
			"app": "core",
			"object": "student",
			"action": "student_create",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-student.action-student_create"
		},
		{
			"app": "core",
			"object": "student",
			"action": "student_update",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-student.action-student_update"
		},
		{
			"app": "core",
			"object": "student",
			"action": "student_destroy",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-student.action-student_destroy"
		},
		{
			"app": "core",
			"object": "student",
			"action": "student_exception",
			"exch": "soomo",
			"routing_key": "soomo.app-core.object-student.action-student_exception"
		},
		{
			"app": "sle",
			"object": "grade",
			"action": "grade_create",
			"exch": "soomo",
			"routing_key": "soomo.app-sle.object-grade.action-grade_create"
		},
		{
			"app": "sle",
			"object": "grade",
			"action": "grade_update",
			"exch": "soomo",
			"routing_key": "soomo.app-sle.object-grade.action-grade_update"
		},
		{
			"app": "sle",
			"object": "grade",
			"action": "grade_exception",
			"exch": "soomo",
			"routing_key": "soomo.app-sle.object-grade.action-grade_exception"
		},
		{
			"app": "sle",
			"object": "hash",
			"action": "grade_broadcast",
			"exch": "soomo",
			"routing_key": "soomo.app-sle.object-hash.action-grade_broadcast"
		},
		{
			"app": "sle",
			"object": "hash",
			"action": "response_broadcast",
			"exch": "soomo",
			"routing_key": "soomo.app-sle.object-hash.action-response_broadcast"
		},
		{
			"app": "discussions",
			"object": "discussion",
			"action": "discussion_create",
			"exch": "soomo",
			"routing_key": "soomo.app-discussions.object-discussion.action-discussion_create"
		},
		{
			"app": "discussions",
			"object": "discussion",
			"action": "discussion_comment",
			"exch": "soomo",
			"routing_key": "soomo.app-discussions.object-discussion.action-discussion_comment"
		},
		{
			"app": "discussions",
			"object": "discussion",
			"action": "discussion_exception",
			"exch": "soomo",
			"routing_key": "soomo.app-discussions.object-discussion.action-discussion_exception"
		},
		{
			"exch": "logs",
			"app": "core",
			"object": "string",
			"action": "log_message",
			"routing_key": "logs.app-core.object-string.action-log_message"
		},
		{
			"exch": "logs",
			"app": "core",
			"object": "hash",
			"action": "log_message",
			"routing_key": "logs.app-core.object-hash.action-log_message"
		},
		{
			"exch": "logs",
			"app": "sle",
			"object": "hash",
			"action": "log_message",
			"routing_key": "logs.app-sle.object-hash.action-log_message"
		},
		{
			"exch": "logs",
			"app": "cac",
			"object": "hash",
			"action": "log_message",
			"routing_key": "logs.app-cac.object-hash.action-log_message"
		}
	],
	"consumer_processes": [
		{
			"app": "ca",
			"name": "ca-consumer",
			"queues": [
				"soomo|student_responses"
			]
		},
		{
			"app": "sle",
			"name": "sle-consumer",
			"queues": [
				"soomo|sle-student",
				"soomo|sle-discussion"
			]
		},
		{
			"app": "bb-pusher",
			"name": "bb-pusher-consumer",
			"queues": [
				"soomo|blackboard-grade"
			]
		},
		{
			"app": "core",
			"name": "logging-consumer",
			"queues": [
				"logs|messages"
			]
		}
	]
}
HEREDOC
end
