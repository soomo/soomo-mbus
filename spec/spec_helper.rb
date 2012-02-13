require 'rspec'
require 'bunny' 
require 'soomo-mbus'

RSpec.configure do | config |
  config.color_enabled = true
  config.formatter     = 'documentation'
end

def standard_mbus_config
  'soomo,rake,rake.*/soomo,activity,activity.*/soomo,email,email.*/soomo,discussion,discussion.*/soomo,response,response.*/blackboard,push,grade.*/customers,student,student.*'
end
