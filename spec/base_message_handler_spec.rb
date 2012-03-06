require 'spec_helper'

# rake spec SPEC=spec/base_message_handler_spec.rb

describe Mbus::BaseMessageHandler do

  before(:all) do
    Mbus::Io.initialize('handler_test', {:start_bunny => false, :silent => true})
    tp = TestProducer.new
    @data = {'group' => "Aerosmith", 'song' => "Walk This Way"}
    json_str = tp.build_message('core', {}, 'walk', 'soomo', 'a.b.c', @data)
    @json_obj = JSON.parse(json_str)
  end

  it 'should implement a constructor and handle method' do
    opts = {:a => 'a'}
    handler = LogMessageMessageHandler.new(opts)
    handler.handle(@json_obj)
    handler.options.should == opts
  end

  it 'should execute its inherited methods' do
    handler = LogMessageMessageHandler.new({})
    handler.handle(@json_obj)
    handler.classname.should == 'LogMessageMessageHandler'
    handler.log_prefix.should == 'handler_test LogMessageMessageHandler'
    handler.app.should == 'core'
    handler.source_app.should == 'core'
    handler.object.should == 'Hash'
    handler.action.should == 'walk'
    handler.exch.should == 'soomo'
    handler.rkey.should == 'a.b.c'
    handler.routing_key.should == 'a.b.c'
    handler.sent_at.should >= (Time.now.to_f) - 3
    handler.sent_at.should <= (Time.now.to_f)
    handler.data.should == @data
    handler.verbose?.should be_false
    handler.silent?.should be_false
  end

end
