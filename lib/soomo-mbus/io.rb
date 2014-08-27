module Mbus

	# :markup: tomdoc
	#
	# Internal: This class, Mbus::Io, is used to perform all IO with RabbitMQ.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class Io

		@@options, @@exchanges, @@queues, @@bunny = {}, {}, {}, nil

		# Public: Initializes IO singletone to communicate with RabbitMQ broker.
		def self.initialize(app_name=nil, opts={})
			@@options  = opts
			@@app_name = app_name
			@@app_name = ENV['MBUS_APP'] if @@app_name.nil? # See Procfile or Rails initializer for MBUS_APP.
			if (@@app_name.nil?)
				puts "#{classname}.initialize ERROR - unable to determine MBUS_APP name" unless silent?
				return
			end
			puts "#{log_prefix}.initialize starting" unless silent?
			Mbus::Config.initialize(@@app_name, options)
			started = (start_bunny?) ? start : false
			puts "#{log_prefix}.initialize - completed, bunny started: #{started}" unless silent?
		end

		# Public: Connects to RabbitMQ broker and setups exchanges and queues.
		def self.start
			begin
				if @@bunny
					puts "#{log_prefix}.start; stopping the previous @@bunny" unless silent?
					@@bunny.stop
				end
			rescue Exception => e1
				puts "#{log_prefix}.start Exception - #{e1.message} #{e1.inspect}" unless silent?
				false
			end

			tries = 0
			begin
				url = Mbus::Config.rabbitmq_url
				puts "#{log_prefix}.starting - rabbitmq_url: #{url}" unless silent?
				@@bunny = Bunny.new(url)
				@@bunny.start
				if Mbus::Config.initialize_exchanges?
					Mbus::Config::exchange_entries_for_app(@@app_name).each { | exch_entry |
						initialize_exchange(exch_entry)
					}
				end
				puts "#{log_prefix}.start - completed" unless silent?
				true
			rescue Bunny::ServerDownError => excp
				puts "#{log_prefix}.start Exception - #{excp.message} #{excp.inspect}" unless silent?
				tries += 1
				if tries <= 3
					sleep(tries) # 1, 2, 3
					retry
				end
			rescue Exception => excp
				puts "#{log_prefix}.start Exception - #{excp.message} #{excp.inspect}" unless silent?
				false
			end
		end

		# Public: Disconnects from RabbitMQ broker.
		def self.shutdown
			puts "#{log_prefix}.shutdown starting..." unless silent?
			@@bunny.stop if @@bunny
			puts "#{log_prefix}.shutdown completed." unless silent?
		end

		# Public: Publishes a message to the message bus.
		def self.send_message(exch_name, json_str_msg, routing_key)
			result = nil
			begin
				with_reconnect_on_failure('send_message') do
					exchange = @@exchanges[exch_name.to_s]
					if exchange && json_str_msg && routing_key
						exchange.publish(json_str_msg, routing_key)
						puts "#{log_prefix}.send_message exch: '#{exchange.name}' key: '#{routing_key}' msg: #{json_str_msg}" if verbose?
						result = json_str_msg
					else
						puts "#{log_prefix}.send_message - invalid value(s) for exch #{exch_name}" unless silent?
					end
				end
			rescue Exception => excp
				puts "#{log_prefix}.send_message Exception - #{excp.message} #{excp.inspect}"
			end
			result
		end

		# Internal: Acks last message received from queue.
		def self.ack_queue(exch_name, queue_name)
			begin
				with_reconnect_on_failure('ack_queue') do
					if queue = @@queues[fullname(exch_name, queue_name)]
						queue.ack
					end
				end
			rescue Exception => excp
				puts "#{log_prefix}.ack_queue Exception on exch: #{exch_name} queue: #{queue_name} - #{excp.message} #{excp.inspect}"
			end
		end

		# Public: Reads a message from the message bus.
		def self.read_message(exch_name, queue_name)
			payload = nil
			begin
				with_reconnect_on_failure('read_message') do
					if queue = @@queues[fullname(exch_name, queue_name)]
						payload = queue.next_message[:payload]
					end
				end
			rescue Exception => e
				puts exception_message('read_message', e, exch_name, queue_name)
			end
			payload
		end


		## Private ##


		def self.reconnect; start; end
		private_class_method :reconnect

		def self.options
			@@options
		end
		private_class_method :options

		def self.exchanges
			@@exchanges
		end
		private_class_method :exchanges

		def self.queues
			@@queues
		end
		private_class_method :queues

		def self.classname
			'Mbus::Io'
		end
		private_class_method :classname

		def self.app_name
			@@app_name
		end
		private_class_method :app_name

		def self.log_prefix
			"#{app_name} #{classname}"
		end
		private_class_method :log_prefix

		def self.verbose?
			@@options[:verbose] && @@options[:verbose] == true
		end
		private_class_method :verbose?

		def self.silent?
			@@options[:silent] && @@options[:silent] == true
		end
		private_class_method :silent?

		def self.start_bunny?
			(@@options[:start_bunny].to_s == 'false') ? false : true
		end
		private_class_method :start_bunny?

		def self.initialize_exchange(exch_entry)
			begin
				ew = Mbus::ExchangeWrapper.new(exch_entry)
				e  = @@bunny.exchange(ew.name, {:type => ew.type_symbol})
				if e
					ew.exchange = e
					@@exchanges[ew.name] = ew
					puts "#{log_prefix}.initialize_exchange - created exchange '#{ew.name}'" unless silent?
					if Mbus::Config::is_consumer?(app_name)
						Mbus::Config::queues_for_app(app_name).each { | queue_entry |
							qw = QueueWrapper.new(queue_entry) # wraps a config entry and the actual queue
							if qw.is_exchange?(ew.name)
								q = @@bunny.queue(qw.name, {:durable => qw.durable?})
								q.bind(ew.name, :key => qw.key)
								qw.queue = q
								@@queues[qw.fullname] = qw
								puts "#{log_prefix}.initialize_exchange - bound '#{qw.fullname}' to '#{qw.key}'" unless silent?
							end
						}
					else
						# producers don't need to define queues
					end
				else
					puts "#{log_prefix}.initialize_exchange - exchange NOT created '#{ew.name}'" unless silent?
				end
			rescue Exception => excp
				puts "#{log_prefix}.initialize_exchange Exception - #{excp.message} #{excp.inspect}" unless silent?
			end
		end
		private_class_method :initialize_exchange

		def self.fullname(exch_name, queue_name)
			"#{exch_name}|#{queue_name}"
		end
		private_class_method :fullname

		def self.exception_message(method, exception, exchange_name='N/A', queue_name='N/A')
			"#{log_prefix}.#{method} Exception on exch: #{exchange_name} queue: #{queue_name}" +
			" - #{exception.message}\n#{exception.inspect}"
		end
		private_class_method :exception_message

		def self.with_reconnect_on_failure(method, &block)
			retries = 0
			delay = 1
			begin
				yield
			rescue Bunny::ProtocolError, Bunny::ConnectionError => e
				puts exception_message(method, e)
				retries += 1
				if retries <= 6 # will sleep at most 2^6 = 64s before process dies.
					delay <<= 1 # 2^x
					puts "Reconnecting after #{delay}s delay (attempt: #{retries})"
					sleep(delay)
					reconnect
					retry
				else
					raise
				end
			end
		end
		private_class_method :with_reconnect_on_failure

	end
end
