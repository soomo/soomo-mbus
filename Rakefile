$:.unshift File.expand_path("../lib", __FILE__)
$: << "."

require 'rubygems'
require 'active_record' 
require 'bundler/gem_tasks'
require 'bunny'
require 'json' 
require 'rspec/core/rake_task'
require 'sqlite3'
require 'soomo-mbus'

# example code
require 'vote'

RSpec::Core::RakeTask.new('spec')

task :environment do 
end
  
namespace :db do
  
  desc "Drop the database."
  task :drop do
    if File.exist?(dbname)
      puts "Removing DB #{dbname}"
      FileUtils.rm(dbname)
      if File.exist?(dbname)
        puts "DB #{dbname} still exists!"
      else
        puts "DB #{dbname} has been removed."
      end
    else
      puts "DB #{dbname} does not exist!"
    end
  end
  
  desc "Create the database."
  task :create do
    puts "Creating DB #{dbname}"
    db = SQLite3::Database.new(dbname)
    if establish_db_connection
      puts "DB created; #{dbname}"
    else
      puts "ERROR: DB NOT created; #{dbname}"
    end
  end
  
  desc "Migrate the database."
  task :migrate do 
    if establish_db_connection
      ActiveRecord::Migrator.migrate("db/migrate/")
    end  
  end

  desc "Create a Vote; vname=hillary cname=obama destroy="
  task :create_vote do
    Mbus::Io.initialize
    # rake db:create_vote vname=hillary cname=obama
    if establish_db_connection
      vote = Vote.new do |v|
        v.voter_name = ENV['vname']
        v.candidate_name = ENV['cname'] 
        v.save!
        v.candidate_name = ENV['cname']
        v.save!
        v.get_lost
        v.destroy if ENV['destroy'] && ENV['destroy'] == 'true'
      end
      puts "vote: #{vote.inspect}"
    end
    Mbus::Io.shutdown
  end
   
end

namespace :mbus do
  
  desc "Create the MBUS_CONFIG environment variable value"
  task :create_mbus_config => :environment do
    sio = StringIO.new
    entries = %w(
      soomo,all,s.#
      soomo,rake,s.rake.*
      soomo,activity,s.activity.*
      soomo,email,s.email.*
      soomo,discussion,s.discussion.*
      soomo,response,s.response.*
      blackboard,push,b.grade.*
      customers,student,c.student.*
    ) 
    max_idx = entries.size - 1
    entries.each_with_index { | entry, idx | 
      sio << entry.strip
      sio << '/' if idx < max_idx
    }
    puts ""
    puts "MBUS_CONFIG=#{sio.string}"
    puts ""
  end
  
  desc "Display the MBUS_CONFIG and RABBITMQ_URL values"
  task :display_mbus_config => :environment do 
    puts "mbus version: #{Mbus::VERSION}" 
    puts "mbus config:  #{Mbus::Config.mbus_config}"
    puts "exchanges: #{Mbus::Config.exchanges.inspect}"
    Mbus::Config.exchanges.each { | exch |
      puts "exchange: #{exch}"
      Mbus::Config.exch_entries(exch).each { | entry |
        puts "  exch|queue|binding: #{entry.raw_value}"
      }
    }
    puts "rabbitmq_url: #{Mbus::Config.rabbitmq_url}"
    puts ""
  end
  
  desc "Display the status of the Mbus"
  task :display_mbus_status => :environment do
    Mbus::Io.initialize
    hash = Mbus::Io.status
    hash.keys.sort.each { | fname | 
      puts "exch/queue #{fname} = #{hash[fname]}"
    }
    Mbus::Io.shutdown
  end
  
  desc "Send message(s), e= k= n=" 
  task :send_messages => :environment do
    ename  = ENV['e'] ||= 'soomo'
    count  = ENV['n'] ||= '1'
    key    = ENV['k'] ||= 'rake.message'
    actual = 0
    Mbus::Io.initialize(false)
    count.to_i.times do | i |
      actual = actual + 1
      msg  = create_message(actual, body="msg sent to key #{unwild_key(key)}")
      Mbus::Io.send_message(ename, msg.to_json, unwild_key(key))
    end
    Mbus::Io.shutdown
  end 
  
  desc "Read messages; e= q= n= "
  task :read_messages => :environment do 
    ename = ENV['e'] ||= 'soomo' 
    qname = ENV['q'] ||= 'rake'
    count = ENV['n'] ||= '1'
    Mbus::Io.initialize
    read_loop(ename, qname, count)
    Mbus::Io.shutdown
  end
  
  desc "Send messages to all exchanges and keys, n="
  task :send_messages_to_all => :environment do
    count  = ENV['n'] ||= '1'
    actual = 0
    Mbus::Io.initialize(false)
    Mbus::Config.exchanges.each { | exch |
      Mbus::Config.exch_entries(exch).each { | entry |
        if entry.queue != 'all'
          count.to_i.times do | i |
            actual = actual + 1
            body = "Msg #{actual} sent to exch '#{entry.exchange}' key: '#{unwild_key(entry.bind_key)}'"
            msg  = create_message(actual, body) 
            Mbus::Io.send_message(entry.exchange, msg.to_json, unwild_key(entry.bind_key))
          end
        end
      }
    }
    Mbus::Io.shutdown
  end
  
  desc "Read messages to all exchanges and keys, n="
  task :read_messages_from_all => :environment do
    count  = ENV['n'] ||= '1'
    actual = 0
    Mbus::Io.initialize
    Mbus::Config.exchanges.each { | exch |
      Mbus::Config.exch_entries(exch).each { | entry |
        read_loop(entry.exchange, entry.queue, count)
      }
    }
    Mbus::Io.shutdown
  end 
  
  desc "Start the SampleConsumerProcess"
  task :sample_process => :environment do
    # rake mbus:sample_process EXCHANGE=soomo QUEUE=rake SLEEP_TIME=20 DB=none
    Mbus::SampleConsumerProcess.new.process_loop
  end 
  
end 

def to_bool(s)
  s.to_s.downcase == 'true'
end

def unwild_key(s)
  s.tr('*#','xx')
end

def create_message(seq, body='hello')
  msg = {}
  msg['seq'] = seq 
  msg['body'] = body 
  msg['sent_at'] = Time.now.to_f
  msg
end

def read_loop(ename, qname, count)
  continue_to_process, actual = true, 0
  while continue_to_process
    msg = Mbus::Io.read_message(ename, qname)
    if msg && (msg != :queue_empty)
      Mbus::Io.ack_queue(ename, qname)
    end  
    if (msg == :queue_empty) || msg.nil?
      continue_to_process = false
      puts "exch: #{ename} queue: #{qname} - empty"
    else
      actual = actual + 1
      puts "exch: #{ename} queue: #{qname} - msg #{actual}: #{msg}"
    end
    if actual >= count.to_i
      continue_to_process = false
    end
  end
end

def env
  ENV['e'] ||= 'development'
end

def dbname
  config = YAML::load(File.open('config/database.yml'))[env]
  config['database']
end

def db_config
  YAML::load(File.open('config/database.yml'))[env]
end 

def establish_db_connection
  ActiveRecord::Base.establish_connection(db_config)
  if ActiveRecord::Base.connection && ActiveRecord::Base.connection.active?
    puts "DB connection established to '#{db_config['database']}' in env '#{env}'"
    true
  else
    puts "ERROR: DB connection NOT established to '#{db_config['database']}' in env '#{env}'" 
    false
  end
end
