require 'spec_helper'

# rake spec SPEC=spec/queue_wrapper_spec.rb

describe Mbus::QueueWrapper do

  it 'should implement a constructor and accessor methods' do
    entry = {'exch' => 'e1', 'name' => 'q1', 'key' => '#.x.#', 'durable' => true, 'ack' => false}
    qw = Mbus::QueueWrapper.new(entry)
    qw.exch.should == 'e1'
    qw.name.should == 'q1'
    qw.key.should == '#.x.#'
    qw.fullname.should == 'e1|q1'
    qw.durable?.should be_true
    qw.ack?.should be_false
    qw.nowait?.should be_true
    qw.is_exchange?(nil).should be_false
    qw.is_exchange?('wrong').should be_false
    qw.is_exchange?('e1').should be_true
  end
  
  it 'should implement the next_read_time! and should_read? methods' do
    entry = {'exch' => 'e1', 'name' => 'q1', 'key' => '#.x.#', 'durable' => true, 'ack' => false}
    qw = Mbus::QueueWrapper.new(entry) 
    qw.next_read_time.should == 0
    qw.should_read?.should be_true
    qw.next_read_time!(1)
    qw.should_read?.should be_false
    sleep 1
    qw.should_read?.should be_true
  end 
  
end
