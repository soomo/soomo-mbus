require 'simplecov'
SimpleCov.start 

require 'rspec'
require 'active_record'
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

class HashLogmessageMessageHandler < Mbus::BaseMessageHandler
end 

class StringLogmessageMessageHandler < Mbus::BaseMessageHandler
  def handle(msg)
    @message = msg
    if data.include?('please disconnect from the database')
      ActiveRecord::Base.connection.disconnect!
    end
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
  "version": "2012-02-29 11:12:25 -0500",
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
      "name": "analytics-grade",
      "key": "#.object-grade.#",
      "exch": "soomo",
      "durable": true,
      "ack": true
    },
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
      "name": "analytics-student",
      "key": "#.object-student.#",
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
      "name": "alerts-exception",
      "key": "#.action-exception",
      "exch": "soomo",
      "durable": true,
      "ack": true
    },
    {
      "exch": "logs",
      "name": "messages",
      "ack": true,
      "key": "#.action-logmessage",
      "durable": true
    }
  ],
  "business_functions": [
    {
      "app": "core",
      "object": "grade",
      "action": "create",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-grade.action-create"
    },
    {
      "app": "core",
      "object": "grade",
      "action": "update",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-grade.action-update"
    },
    {
      "app": "core",
      "object": "grade",
      "action": "exception",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-grade.action-exception"
    },
    {
      "app": "core",
      "object": "student",
      "action": "create",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-student.action-create"
    },
    {
      "app": "core",
      "object": "student",
      "action": "update",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-student.action-update"
    },
    {
      "app": "core",
      "object": "student",
      "action": "destroy",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-student.action-destroy"
    },
    {
      "app": "core",
      "object": "student",
      "action": "exception",
      "exch": "soomo",
      "routing_key": "soomo.app-core.object-student.action-exception"
    },
    {
      "app": "sle",
      "object": "grade",
      "action": "create",
      "exch": "soomo",
      "routing_key": "soomo.app-sle.object-grade.action-create"
    },
    {
      "app": "sle",
      "object": "grade",
      "action": "update",
      "exch": "soomo",
      "routing_key": "soomo.app-sle.object-grade.action-update"
    },
    {
      "app": "sle",
      "object": "grade",
      "action": "exception",
      "exch": "soomo",
      "routing_key": "soomo.app-sle.object-grade.action-exception"
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
      "action": "create",
      "exch": "soomo",
      "routing_key": "soomo.app-discussions.object-discussion.action-create"
    },
    {
      "app": "discussions",
      "object": "discussion",
      "action": "comment",
      "exch": "soomo",
      "routing_key": "soomo.app-discussions.object-discussion.action-comment"
    },
    {
      "app": "discussions",
      "object": "discussion",
      "action": "exception",
      "exch": "soomo",
      "routing_key": "soomo.app-discussions.object-discussion.action-exception"
    },
    {
      "exch": "logs",
      "app": "core",
      "object": "string",
      "action": "logmessage",
      "routing_key": "logs.app-core.object-string.action-logmessage"
    },
    {
      "exch": "logs",
      "app": "core",
      "object": "hash",
      "action": "logmessage",
      "routing_key": "logs.app-core.object-hash.action-logmessage"
    },
    {
      "exch": "logs",
      "app": "sle",
      "object": "string",
      "action": "logmessage",
      "routing_key": "logs.app-sle.object-string.action-logmessage"
    },
    {
      "exch": "logs",
      "app": "cac",
      "object": "string",
      "action": "logmessage",
      "routing_key": "logs.app-cac.object-string.action-logmessage"
    }
  ],
  "consumer_processes": [
    {
      "app": "ca",
      "name": "student-responses-consumer",
      "queues": [
        "student_responses"
      ]
    },
    {
      "app": "analytics",
      "name": "analytics-consumer",
      "queues": [
        "soomo|analytics-grade",
        "soomo|analytics-student"
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
      "app": "logging",
      "name": "logging-consumer",
      "queues": [
        "logs|messages"
      ]
    }
  ]
}
HEREDOC
end
