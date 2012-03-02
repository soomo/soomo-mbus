require 'spec_helper'

# rake spec SPEC=spec/base_consumer_process_spec.rb

describe Mbus::BaseConsumerProcess do
  
  before(:each) do 
    set_local_redis_config
    ENV['MBUS_APP']      = nil
    ENV['MBUS_HOME']     = config_location_local_rspec
    ENV['MBUS_QE_TIME']  = nil
    ENV['MBUS_DBC_TIME'] = nil
    ENV['MBUS_MAX_SLEEPS'] = nil 
    ENV['DATABASE_URL']  = 'none'
    @opts = {:test_mode => true, :start_bunny => false, :silent => true}
  end
  
  it 'should determine its name from environment variable MBUS_APP' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.app_name.should == 'test_app'
    process.shutdown
    
    ENV['MBUS_APP'] = nil
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.app_name.should be_nil
    process.shutdown
  end
  
  it 'should determine its queue_empty_sleep_time from environment variable MBUS_QE_TIME' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.queue_empty_sleep_time.should == 15
    process.shutdown 
    
    ENV['MBUS_QE_TIME'] = '16'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.queue_empty_sleep_time.should == 16
    process.shutdown  
  end 
  
  it 'should determine its db_disconnect_sleep_time from environment variable MBUS_DBC_TIME' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.db_disconnect_sleep_time.should == 20
    process.shutdown 
    
    ENV['MBUS_DBC_TIME'] = '21'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.db_disconnect_sleep_time.should == 21
    process.shutdown  
  end
  
  it 'should determine its max_sleeps count from environment variable MBUS_MAX_SLEEPS' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.max_sleeps.should == -1
    process.shutdown 
    
    ENV['MBUS_MAX_SLEEPS'] = '3'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.max_sleeps.should == 3
    process.shutdown  
  end
  
  it 'should determine its database_url from environment variable MBUS_DB' do
    ENV['MBUS_APP'] = 'test_app'
    ENV['DATABASE_URL'] = 'postgres://localhost'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.database_url.should == 'postgres://localhost'
    process.use_database?.should be_true
    process.shutdown 
    
    ENV['MBUS_APP'] = 'test_app' 
    ENV['MBUS_DB']  = 'OTHER_DATABASE_URL'
    ENV['DATABASE_URL'] = 'postgres://localhost'
    ENV['OTHER_DATABASE_URL'] = 'postgres://otherdb'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.database_url.should == 'postgres://otherdb'
    process.use_database?.should be_true
    process.shutdown 
    
    ENV['MBUS_APP'] = 'test_app' 
    ENV['MBUS_DB']  = 'none'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.database_url.should == 'none' 
    process.use_database?.should be_false
    process.shutdown
  end 
  
  it 'should determine its queues from the configuration at MBUS_HOME' do
    ENV['MBUS_APP'] = 'logging-consumer'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.app_name.should == 'logging-consumer'
    qnames = process.queues_list.collect { | qw | qw.fullname }
    process.continue_to_process.should be_true 
    qnames.should == ["logs|messages"]
    process.shutdown
    
    ENV['MBUS_APP'] = nil
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.app_name.should be_nil
    qnames = process.queues_list.collect { | qw | qw.fullname }
    process.continue_to_process.should be_false
    qnames.should == []
    process.shutdown
    
    ENV['MBUS_APP'] = 'undefined-consumer'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.app_name.should == 'undefined-consumer'
    qnames = process.queues_list.collect { | qw | qw.fullname }
    process.continue_to_process.should be_false
    qnames.should == []
    process.shutdown 
  end 

  it 'should implement its standard methods' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new({:test_mode => false, :start_bunny => false, :silent => true})
    process.app_name.should == 'test_app'
    process.classname.should == 'Mbus::BaseConsumerProcess' 
    process.log_prefix.should == 'test_app Mbus::BaseConsumerProcess'
    process.use_database?.should be_false
    process.database_url.should == 'none'
    process.database_connection_active?.should be_false
    process.establish_db_connection.should be_false
    process.shutdown
  end
  
  it 'should connect to a postgres database' do
    # This test assumes that you have the postgres database installed locally
    ENV['MBUS_APP'] = 'test_app'
    ENV['MBUS_DB']  = nil
    ENV['DATABASE_URL'] = 'postgres://localhost'
    process = Mbus::BaseConsumerProcess.new(@opts)
    process.use_database?.should be_true
    process.database_url.should == 'postgres://localhost'
    process.establish_db_connection.should be_true
    process.database_connection_active?.should be_true
    process.shutdown
  end
  
  it 'should implement method handler_classname' do
    ENV['MBUS_APP'] = 'test_app'
    process = Mbus::BaseConsumerProcess.new(@opts)

    tp = TestProducer.new
    data = {:group => "Salt-N-Pepa", :song => "Push It"}
    
    json_str = tp.build_message('core', {}, 'some_action', 'soomo', 'a.b.c', data)
    json_obj = JSON.parse(json_str)
    process.classname_map.size.should == 0 
    cn = process.handler_classname(json_obj)
    cn.should == 'SomeActionMessageHandler'
    process.classname_map.size.should == 1 
    process.classname_map['some_action'].should == 'SomeActionMessageHandler'

    json_str = tp.build_message('core', {}, 'awesome_possum', 'soomo', 'x.y.z', data)
    json_obj = JSON.parse(json_str)
    cn = process.handler_classname(json_obj)
    cn.should == 'AwesomePossumMessageHandler'
    process.classname_map.size.should == 2 
    process.classname_map['awesome_possum'].should == 'AwesomePossumMessageHandler'

    json_str = tp.build_message('core', {}, 'awesome-possum', 'soomo', 'x.y.z', data)
    json_obj = JSON.parse(json_str)
    cn = process.handler_classname(json_obj)
    cn.should == 'AwesomePossumMessageHandler'
    process.classname_map.size.should == 3 
    process.classname_map['awesome-possum'].should == 'AwesomePossumMessageHandler'
      
    cn = process.handler_classname(json_obj)
    cn.should == 'AwesomePossumMessageHandler'
    process.classname_map.size.should == 3 
    process.classname_map['awesome-possum'].should == 'AwesomePossumMessageHandler'
    
    process.shutdown 
  end 
  
  it 'should execute its run loop with no database and no sleeps' do
    # First, drain the queue of messages. 
    ENV['MBUS_APP'] = 'logging-consumer' 
    Mbus::Io.initialize('logging-consumer', {:verbose => false, :silent => true})
    Mbus::Io.app_name.should == 'logging-consumer'
    continue_to_process = true
    while continue_to_process
      msg = Mbus::Io.read_message('logs', 'messages')
      if (msg == :queue_empty) || msg.nil?
        continue_to_process = false
      else
        #puts "base_consumer_process_spec draining msg: #{msg}"
        Mbus::Io.ack_queue('logs', 'messages')
      end
    end
    Mbus::Io.shutdown
    
    # Next, send some new log messages
    ENV['MBUS_APP'] = 'core'
    Mbus::Io.initialize('core', {:verbose => false, :silent => true})
    Mbus::Io.app_name.should == 'core'
    tp = TestProducer.new
    13.times do | i |
      data = {:n => i, :epoch => Time.now.to_i}
      # produce messages for which will be handled in BaseConsumerProcess by
      # instances of class LogMessageMessageHandler
      msg  = tp.doit(data, 'log_message')
      msg  = tp.doit("String message #{i} at #{Time.now.to_i}", 'log_message')
    end
    Mbus::Io.shutdown 
    
    # Run the consumer to process the new messages
    ENV['MBUS_APP'] = 'logging-consumer'
    ENV['MBUS_QE_TIME'] = 'stop' 
    process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
    process.process_loop
    process.messages_read.should == 26 
    process.messages_processed.should == 26
    process.max_sleeps.should  == -1
    process.sleep_count.should == 0
    process.db_disconnected_count.should == 0
    
    # Run the consumer again, there should be no messages
    ENV['MBUS_APP'] = 'logging-consumer'
    ENV['MBUS_QE_TIME'] = 'stop' 
    process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
    process.process_loop
    process.messages_read.should == 0 
    process.messages_read.should == 0 
  end
  
  it 'should execute its run loop with a database, sleeps, and a DB disconnect' do
    # First, drain the queue of messages. 
    ENV['MBUS_APP'] = 'logging-consumer' 
    Mbus::Io.initialize('logging-consumer', {:verbose => false, :silent => true})
    Mbus::Io.app_name.should == 'logging-consumer'
    continue_to_process = true
    while continue_to_process
      msg = Mbus::Io.read_message('logs', 'messages')
      if (msg == :queue_empty) || msg.nil?
        continue_to_process = false
      else
        #puts "base_consumer_process_spec draining msg: #{msg}"
        Mbus::Io.ack_queue('logs', 'messages')
      end
    end
    Mbus::Io.shutdown
    
    # Next, send some new log messages
    ENV['MBUS_APP'] = 'core'
    Mbus::Io.initialize('core', {:verbose => false, :silent => true})
    Mbus::Io.app_name.should == 'core'
    tp = TestProducer.new
    13.times do | i |
      data = {:n => i, :epoch => Time.now.to_i}
      # produce messages for which will be handled in BaseConsumerProcess by
      # instances of HashLogmessageMessageHandler and StringLogmessageMessageHandler
      msg  = tp.doit(data, 'log_message')
      if i == 11
        msg = tp.doit("This is a test, please disconnect from the database, at #{Time.now.to_i}", 'log_message')
      else
        msg = tp.doit("String message #{i} at #{Time.now.to_i}", 'log_message')
      end
    end
    Mbus::Io.shutdown 
    
    # Run the consumer to process the new messages
    # It should become disconnected from the DB, then reestablish
    # the DB connection and resume processing all 26 messages.
    ENV['MBUS_APP'] = 'logging-consumer'
    ENV['MBUS_QE_TIME'] = '1'
    ENV['MBUS_DBC_TIME'] = '1'
    ENV['MBUS_MAX_SLEEPS'] = '3'
    ENV['MBUS_DB']  = nil
    ENV['DATABASE_URL'] = 'postgres://localhost'   
    process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
    process.process_loop
    process.messages_read.should == 26 
    process.messages_processed.should == 26
    process.max_sleeps.should  == 3
    process.sleep_count.should == 3
    process.db_disconnected_count.should == 1
    
    # Run the consumer again, there should be no messages
    ENV['MBUS_APP'] = 'logging-consumer'
    ENV['MBUS_QE_TIME'] = 'stop'
    ENV['MBUS_DBC_TIME'] = '1'
    ENV['MBUS_MAX_SLEEPS'] = '2'
    ENV['MBUS_DB']  = nil
    ENV['DATABASE_URL'] = 'postgres://localhost'
    process = Mbus::BaseConsumerProcess.new({:verbose => false, :silent => true})
    process.process_loop
    process.messages_read.should == 0 
    process.messages_processed.should == 0
    process.db_disconnected_count.should == 0 
  end

end
  