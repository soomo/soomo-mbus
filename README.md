Soomo Publishing Message Bus (soomo-mbus)
=========================================

Purpose
-------
Reliable and timely inter-application communication.

Implementation
--------------
Use RabbitMQ as the message delivery mechanism.

Packaged as a gem, with no dependency on Rails.  Usable in Sinatra or daemons.

Sample environment variables:
  MBUS_CONFIG_DEFAULT=test_exch,test_queue,produce,test.*
  MBUS_CONFIG_TEST_CONSUMER=test_exch,test_queue,consume,test.* 
  RABBITMQ_URL=amqp://localhost

TODO - document further