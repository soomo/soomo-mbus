Soomo Publishing Message Bus (Mbus)
===================================

Purpose
-------
Reliable and timely inter-application communication.

Implementation
--------------
Use RabbitMQ as the primary message delivery mechanism, and Redis 
as the secondary or fail-over mechanism.

Packaged as a gem, with no dependency on Rails.  Usable in Sinatra or daemons.

Optional Rails Engine, which uses the message-bus gem, for monitoring and diagnostics.
Engine provides a UI to view the state of RabbitMQ and Redis.

The gem implements modules, which can easily be mixed-in by user applications.

Module Mbus::Producer
--------------------
Something significant happened in an application, so put a message on the bus.

Goal: Have just one public API method - 'enqueue_on_bus(opts={})'.
Goal: By default, have the bus, not the sender, determine the target exchange and queue.
Goal: By default, have the bus, not the sender, format the JSON message (from self and opts).
Goal: Enable the sender to specify the target if necessary; :exch and :queue in opts hash.
Goal: Enable the sender to format the JSON message if necessary; :message in opts hash.
Goal: Implement message versioning; use Mbus::VERSION.
Goal: Simple message design for Models - just classname, id, and action.

Question: Do we need to include the 'source app' in the message?

Generic examples:
  enqueue_on_bus {:action => 'process'}
  enqueue_on_bus {:action => 'process', :queue='students', :message => '{... JSON string ...}'}
  
ActiveRecord::Base hook-method examples:
  after_create  :enqueue_on_bus {:action => 'create'}
  after_save    :enqueue_on_bus {:action => 'save'} 
  after_update  :enqueue_on_bus {:action => 'update'} 
  after_destroy :enqueue_on_bus {:action => 'destroy'}

ActionMailer::Base examples:
  enqueue_on_bus {:action => 'deliver'} 
  

TODO:
-----
  Understand the Soomo requirements and use cases better.
  Understand the use and configuration of RabbitMQ at Heroku.
  
Running the Prototype:
----------------------
  Setup the Gemset:
  rvm use ruby-1.9.2-p290
  rvm gemset create message-bus
  rvm use ruby-1.9.2-p290@message-bus 
  bundle install
   
  Setup the sqlite3 database:
  rake db:drop
  rake db:create
  rake db:migrate
  
  Create some Vote models.  AR callbacks, and other method calls, put messages on rabbitmq.
  rake db:create_vote cname=obama vname=hillary
  
  Read the messages from rabbitmq:
  rake rmq:read_messages n=99  


Initial Heroku testing:
-----------------------
  Staging RabbitMQ
  Current 'soomo.events' exchange; create another exchange for testing.

