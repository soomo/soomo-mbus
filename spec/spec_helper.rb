require 'rspec'
require 'active_record'
require 'bunny' 
require 'soomo-mbus'

RSpec.configure do | config |
  config.color_enabled = true
  config.formatter     = 'documentation'
end

def default_config_env_var
  Mbus::Config::DEFAULT_CONFIG_ENV_VAR
end

def standard_config_value
  sio = StringIO.new
  sio << 'test_exch,test_queue1,produce,test.this.*'
  sio << '/test_exch,test_queue2,produce,test.that.*'
  sio << '/vendor1_exch,vendor1_queue,consume,vendor1.*'
  sio << '/vendor2_exch,vendor2_queue,produce,vendor1.*'
  sio.string
end
