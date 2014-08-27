# Soomo Publishing Message Bus (soomo-mbus)

## Purpose

Reliable and timely inter-application queue-based communication.  Intended for
a distributed system consisting of several Rails or other applications.

## Implementation

Ruby programming language, with RabbitMQ as the message delivery mechanism,
and Redis as the centralized configuration data store.

## Distribution

Packaged as a gem with limited dependencies; Rails not required.  Usable, for example,
in Sinatra web applications or simple ruby daemons.

## Key Design Feature Overview

* Centralized configuration in JSON format, and stored in n-number of Redis locations for fail-over.
* The JSON configuration is created by class Mbus::ConfigBuilder.  Modify it as necessary.
* Configuration of individual applications and processes via "MBUS_" environment variables.
* Application processes may be either producers or consumers of messages.
* Message producers use the "mbus_enqueue(...)" method of the Mbus::Producer module.
* Message producers don't have to know about exchange, queue, and routing details - the message bus
  does this automatically based on the configuration of the business function being executed.
* Formatting of the messages can be left to the message bus itself.  But custom formatting is supported, too.
* Messages are in JSON format.
* Message consumers simply use class Mbus::BaseConsumerProcess "as-is", and implement message handler classes.
* Consumer processes can consume messages from one or more queues, per their configuration.
* Consumer processes may use the PostgreSQL database.  Others not supported in this version.

## Configuration Creation and Deployment

First, modify class Mbus::ConfigBuilder as necessary for your system and business application.
Then generate the configuration JSON with `rake mbus:config:create`.  Running this rake task
will also "sanity-check" the generated JSON, and report if it is valid or not.  It is recommended
that you visually verify this generated JSON.

The next step is to actually deploy the JSON content to your Redis server(s).  This can be done
with `rake mbus:config:deploy`; specify a `loc=` value.

Then, set the 'MBUS_HOME' environment variable for each node of your system which will use the
message bus, either as a producer or consumer of messages.  This value must contain ^-delimited list
of the Redis configuration locations.  Each location specifies a Redis URL as well as a Redis Key
where the configuration JSON is located, for example.

    redis://host1234:6379/#MBUS_CONFIG^redis://host2345:6379/#MBUS_CONFIG

`rake mbus:config:display_deployed` can be used to display the deployed configuration.
If you don't provide a `loc=` parameter, it will look at the first entry in your local MBUS_HOME
environment variable.

The RABBITMQ_URL environment variable must also be set, such as:

    RABBITMQ_URL=amqp://localhost

## Business Function Traceability Report

This report is generated whenever any of the following three rake tasks are executed:

    rake mbus:config:create
    rake mbus:config:deploy
    rake mbus:config:display_deployed

The purpose of the report is to make it easy for you to trace messages for a given business function
from its origin, through RabbitMQ, and to the eventual consumer(s) of the message.  Reading this
report is easier than visually scanning, and scrolling, through the configuration JSON.

The following are two example report entries.  The first entry indicates that there are no
queues or consumers associated with the business function, while the second entry does.
The indentation is intended to imply heirarchy.

    Business Function: core, grade_create -> 'soomo.app-core.object-grade.action-grade_create'
      Exchange:  'soomo'  type: topic  persistent: true  mandatory: false  immediate: false

    Business Function: sle, response_broadcast -> 'soomo.app-sle.object-hash.action-response_broadcast'
      Exchange:  'soomo'  type: topic  persistent: true  mandatory: false  immediate: false
        Queue:   'student_responses'  key: #.action-response_broadcast  durable: true  ack: true
          Consumer: 'ca-consumer' in app: 'ca'

## Application and Message Bus Startup

The "MBUS_APP" environment variable must be set for each producer or consumer process
in your system.  This defines its unique name, and correlates it to the pertinent information,
such as exchanges, queues, and business functions in the configuration JSON.

Invoke `Mbus::Io.initialize('app-name', options)` to start the message bus.  The `app-name`
value corresponds to the MBUS_APP value.  The second argument, options, is a hash with the
following optional keys and defaults:

     key        default       purpose
    :verbose    false         Used in logging
    :silent     false         Used in logging

A Rails initializer is an appropriate place to invoke `Mbus::Io.initialize`.

## Centralized JSON Configuration

By extracting this information into a configuration file, your application code becomes much
less cluttered with these configuration details.  Furthermore, the configuration JSON can
be modified and redeployed as needed, without having to redeploy your application code.

There are four entry types in the JSON configuration file - exchanges, business_functions, queues,
and consumer_processes.  The values in these entries are correlated to each other.

Exchanges are defined with entries like the following.  The four RabbitMQ exchange types are supported,
with "topic" being the default and preferred.  Boolean values should be provided for the persistent,
mandatory, and immediate properties.

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
    ]

Business functions are defined with entries like the following.  The "app" value correlates
to the "MBUS_APP" environment variable value.  The "exch" value correlates to the exchange
entries defined above.  The "object" value is the name of your business object, such as an
ActiveRecord model.  The "action" correlates to a method that is being performed on the
business object.  You need to define business function entries for each logical message type
that you plan to put on the bus; undefined messages will not be sent by the bus.

    "business_functions": [
      {
        "app": "core",
        "object": "grade",
        "action": "create",
        "exch": "soomo",
        "routing_key": "soomo.app-core.object-grade.action-create"
      },

The routing key values are automatically calculated by class Mbus::ConfigBuilder.  Their
format is standard and contains the `app-`, `object-`, and `action-` prefixes to disambiguate
the names.

Queues are defined as follows.  The durable and ack (i.e. - acknowledge) value must be
boolean values; true or false.  The key value is a RabbitMQ routing key.  A nice feature of AMQP
and RabbitMQ is that messages can be sent to multiple queues, depending on the routing
key of the message and the key definitions for the queues.

    "queues": [
    {
      "name": "sle-student",
      "key": "#.object-student.#",
      "exch": "soomo",
      "durable": true,
      "ack": true
    },

The last of the four main entry types is "consumer_processes".  They are defined as shown
below.  The "name" value corresponds to their MBUS_APP name, and the "queues" value is
a list of the one or more queues it reads.  These are concatinated values consisting
of the exchange name, a vertibar (|), and the queue name.

    "consumer_processes": [
      {
        "app": "analytics",
        "name": "analytics-consumer",
        "queues": [
          "soomo|analytics-grade",
          "soomo|analytics-student"
        ]
      },

## Producers

Producer processes don't need to be concerned with exchange, queue, or routing key details.
They just need to mixin the `Mbus::Producer` module, and invoke `mbus_enqueue` to put a
business object on the bus.  Class `TestProducer` below is an example.

    class TestProducer
      include Mbus::Producer
      def doit(obj, action, custom_json_msg_string=nil)
        mbus_enqueue(obj, action, custom_json_msg_string)
      end
    end

When `mbus_enqueue` is invoked, the message bus will send the message to the appropriate
exchanges and routing key per your JSON configuration.  Messages for undefined business
functions, however, will not be sent.

## Messages

Messages put on the bus are in JSON format and look like the following.  The value for "data"
is you business object in JSON format; either an auto-formatted or custom-formatted value.
The bus itself adds the other entries in the message, such as "app", "object", and "action".

    {
      "app": "core",
      "object": "Song",
      "action": "like",
      "exch": "soomo",
      "rkey": "a.b.c",
      "sent_at": 1330260691.560673,
      "data": {
        "group": "Salt-N-Pepa",
        "song": "Push It"
      }
    }

## Consumer Processes

Class Mbus::BaseConsumerProcess can be used "as is" for any and all of your processes
which read messages from the queues.  You can optionally subclass this class as necessary.

Mbus::BaseConsumerProcess provides standard initialization and run-loop processing.
In addition to the required MBUS_HOME and MBUS_APP environment variables, several others
may be used.  These are:

*  DATABASE_URL - url of your PostgreSQL database, such as 'postgres://localhost'.  The value 'none'
indicates that the process doesn't use a database.
*  MBUS_DB - alternative databases url; overrides the value of DATABASE_URL.
*  MBUS_QE_TIME - The number of seconds to sleep if there are no messages on the queue(s).  Defaults to 15.  The
value 'stop' can be used to have the process stop processing once the queue(s) reach an empty state.
*  MBUS_DBC_TIME - The number of seconds to sleep if the database connection is lost.  Defaults to 20.
*  MBUS_MAX_SLEEPS - The maximum number of sleep cycles for the process.  The default is -1, meaning no limit.

The run loop of Mbus::BaseConsumerProcess will check that the database connection exists, if you're
using a database.  If the connection is broken, then the process will sleep for MBUS_DBC_TIME seconds, then
attempt to reconnect.  The awake/check-connectivity/sleep cycle will continue until such time
as the reconnect is successful.

After processing each message, the run loop will also "ack" the message if that queue had been defined
to have its messages acknowledged.

If a process reads from multiple queues, then they will be read in a round-robin manner.  If one of
the queues becomes empty, then the logic Mbus::BaseConsumerProcess won't read it again for MBUS_QE_TIME
seconds.

## Message Handlers

For every message received, Mbus::BaseConsumerProcess will examine the message and attempt to
instantiate the corresponding message-handler class.  It does this by converting the "action"
value in the message to a classname prefix, then adds the suffix "MessageHandler".  The action
value will be translated into capitalized words, and the underscores will be removed.  For example,
action "student_updated" would translate to class "StudentUpdatedMessageHandler".  This design
thus uses "convention over configuration".  Your hander implementation classes should extend class
Mbus::BaseMessageHandler, which offers standard methods to access the components of the message.

If the class exists, then Mbus::BaseConsumerProcess will invoke its' "handle(msg)" method, and
pass it the message.  It's up to the Handler class to implement the appropriate logic.  The Handler
class should not attempt to "ack" the message, however, as the Mbus::BaseConsumerProcess run loop
does this automatically.

## Rake Tasks

The following rake tasks are available.  The "mbus_db" tasks are simply for ActiveRecord
callback examples using the sqlite database.

    rake mbus:config:create            # Create the configuration JSON
    rake mbus:config:deploy            # Create then deploy the configuration JSON, loc=
    rake mbus:config:display_deployed  # Display the deployed configuration JSON
    rake mbus:config:setup             # Setup the exchanges and queues per the centralized config.
    rake mbus:read_messages            # Read messages; a= e= q= n=
    rake mbus:read_messages_from_all   # Read messages from all exchanges and keys, n=
    rake mbus:send_messages            # Send message(s), e= k= n=

    rake mbus_db:create                # Create the (example sqlite) database.
    rake mbus_db:create_grade          # Create a Grade(s), n=
    rake mbus_db:drop                  # Drop the database.
    rake mbus_db:migrate               # Migrate the database.


Shell script `test_rake_tasks.sh` can be used to run all of the tasks to test them on your system.

## Testing with RSpec

Run `rake spec`.  All 72 tests should pass.  Code coverage report is also generated via the simplecov gem.
97.66% of the code is covered by these tests; the uncovered code is Exception handling.

