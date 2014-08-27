
class SampleProducer
	include Mbus::Producer
	def send(obj, action, custom_json_msg_string=nil)
		mbus_enqueue(obj, action, custom_json_msg_string)
	end
end

namespace :mbus do

	desc "Display the status of the Mbus"
	task :status => :environment do
		app = ENV['app'] ||= 'all'
		ENV['MBUS_APP'] = app
		opts = {:verbose => true, :silent => false}
		Mbus::Io.initialize(app, opts)
		hash = Mbus::Io.status
		hash.keys.sort.each { | fname |
			puts "exch/queue #{fname} = #{hash[fname]}"
		}
		Mbus::Io.shutdown
	end

	desc "Send message(s), e= k= n="
	task :send_messages => :environment do
		app    = ENV['app'] ||= 'core'
		ename  = ENV['e']   ||= 'logs'
		count  = ENV['n']   ||= '10'
		key    = ENV['k']   ||= 'logs.app-core.object-hash.action-log_message'
		actual = 0
		puts "command-line params:"
		puts "  sending app (app=): #{app}"
		puts "  to exchange (e=):   #{ename}"
		puts "  routing key (k=):   #{key}"
		puts "  message count (n=): #{count}"

		producer = SampleProducer.new
		Mbus::Io.initialize(app, init_options)
		count.to_i.times do | i |
			actual = actual + 1
			msg  = create_message(actual, "msg sent to key #{unwild_key(key)}")
			producer.send(msg, "log_message")
		end
		Mbus::Io.shutdown
	end

	desc "Read messages; a= e= q= n= "
	task :read_messages => :environment do
		app   = ENV['app'] ||= 'logging-consumer'
		ename = ENV['e']   ||= 'logs'
		qname = ENV['q']   ||= 'messages'
		count = ENV['n']   ||= '10'
		puts "command-line params:"
		puts "  consumer app (app=): #{app}"
		puts "  from exchange (e=):  #{ename}"
		puts "  queue (q=):          #{qname}"
		puts "  message count (n=):  #{count}"
		Mbus::Io.initialize(app, init_options)
		read_loop(ename, qname, count)
		Mbus::Io.shutdown
	end

	desc "Read messages from all exchanges and keys, n="
	task :read_messages_from_all => :environment do
		app    = ENV['app'] ||= 'all'
		count  = ENV['n']   ||= '5'
		Mbus::Io.initialize(app, init_options)
		Mbus::Config.exchange_entries_for_app(app).each { | entry |
			exch_name = entry['name']
			Mbus::Config::queues_for_app(app).each { | queue_entry |
				if exch_name = queue_entry['exch']
					read_loop(exch_name, queue_entry['name'], count)
				end
			}
		}
		Mbus::Io.shutdown
	end

end

def init_options
	opts = {}
	opts[:verbose] = true
	opts[:silent]  = false
	opts[:rabbitmq_url] = ENV['rabbitmq_url'] if ENV['rabbitmq_url']
	opts[:start_bunny]  = ENV['start_bunny']  if ENV['start_bunny']
	opts[:initialize_exchanges] = ENV['init_exchanges'] if ENV['init_exchanges']
	opts
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

