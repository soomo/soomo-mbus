# :markup: tomdoc

# Internal: This class, Mbus::Vote, demonstrates the use of the
# Mbus::Producer mixin.  Both regular methods, and ActiveRecord
# hooks, cause messages to be put on the bus via the 'enqueue_on_bus'
# method of Mbus::Producer.
#
# Chris Joakim, Locomotive LLC, 2012/02/11

class Vote < ActiveRecord::Base
  
  include Mbus::Producer

  after_create  { enqueue_on_bus('create') }
  after_update  { enqueue_on_bus('update') }
  after_destroy { enqueue_on_bus('destroy') }

  def get_lost
    enqueue_on_bus({:action => 'got_lost'})
  end
  
  def enqueue_on_bus(action='?')
    msg = {}
    msg['model'] = self.class.name
    msg['id'] = id 
    msg['action'] = action 
    msg['sent_at'] = Time.now.to_f
    msg 
    Mbus::Io.send_message('soomo', msg.to_json, 's.rake.vote')
  end
  
end 
