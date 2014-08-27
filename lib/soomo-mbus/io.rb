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
			@@app_name = app_name || ENV['MBUS_APP']

			if @@app_name.nil?
				log :error, "unable to determine MBUS_APP name" unless silent?
				return
			end

			Mbus::Config.initialize(@@app_name, options)
			start_bunny? ? start : false
		end

		# Public: Connects to RabbitMQ broker and setups exchanges and queues.
		def self.start
			begin
				@@bunny.stop if @@bunny
			rescue => e
				log_exception('start', e)
				false
			end

			tries = 0
			begin
				url = Mbus::Config.rabbitmq_url

				log :info, "starting", rabbitmq_url: url unless silent?
				@@bunny = Bunny.new(url)
				@@bunny.start
				log :info, "started" unless silent?

				log :info, "setting up exchanges and queues" unless silent?
				setup_exchanges(Mbus::Config.exchange_entries_for_app(@@app_name))
				setup_queues(Mbus::Config.queues_for_app(@@app_name)) if Mbus::Config.is_consumer?
				log :info, "setup exchanges and queues" unless silent?

				true
			rescue Bunny::ServerDownError => e
				log_exception('start', e)
				tries += 1
				if tries <= 3
					sleep(tries) # 1, 2, 3
					retry
				end
				false
			rescue => e
				log_exception('start', e)
				false
			end
		end


		# Public: Disconnects from RabbitMQ broker.
		def self.shutdown
			log :info, "shutting down" unless silent?
			@@bunny.stop if @@bunny
			log :info, "shutdown complete" unless silent?
		end


		# Public: Publishes a message to the message bus.
		def self.send_message(exch_name, json_str_msg, routing_key)
			result = nil
			begin
				with_reconnect_on_failure('send_message') do
					exchange = @@exchanges[exch_name.to_s]
					if exchange && json_str_msg && routing_key
						exchange.publish(json_str_msg, routing_key)
						log :info, "", action: 'send_message', exch: exchange.name, key: routing_key, msg: json_str_msg if verbose?
						result = json_str_msg
					else
						log :warn, "invalid value(s) for exchange", action: 'send_message', exch: exch_name unless silent?
					end
				end
			rescue => e
				log_exception('send_message', e)
			end
			result
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
			rescue => e
				log_exception_message('read_message', e, exch_name, queue_name)
			end
			payload
		end


		# Internal: Acks last message received from queue.
		def self.ack_queue(exch_name, queue_name)
			begin
				with_reconnect_on_failure('ack_queue') do
					if queue = @@queues[fullname(exch_name, queue_name)]
						queue.ack
					end
				end
			rescue => e
				log_exception_message('ack_queue', e, exch_name, queue_name)
			end
		end


		# Internal: Sets up exchanges.  Should only be used within Mbus.
		def self.setup_exchanges(exchange_config_entries)
			exchange_config_entries.each do |exchange_config|
				ew = Mbus::ExchangeWrapper.new(exchange_config)
				if e  = @@bunny.exchange(ew.name, {:type => ew.type_symbol})
					ew.exchange = e
					@@exchanges[ew.name] = ew
					log :info, "created exchange", exch: ew.name unless silent?
				else
					log "exchange NOT created", exch: ew.name unless silent?
				end
			end

			return @@exchanges
		end


		# Internal: Sets up queues.  Should only be used within Mbus.
		def self.setup_queues(queue_config_entries)
			queue_config_entries.each do |queue_config|
				qw = QueueWrapper.new(queue_config)
				q = @@bunny.queue(qw.name, {:durable => qw.durable?})
				if ew = @@exchanges[qw.exch]
					q.bind(ew.name, :key => qw.key)
					qw.queue = q
					@@queues[qw.fullname] = qw
					log "bound queue to exchange", exch: ew.name, queue: qw.name, key: qw.key unless silent?
				end
			end

			return @@queues
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

		def self.fullname(exch_name, queue_name)
			"#{exch_name}|#{queue_name}"
		end
		private_class_method :fullname

		def self.exception_message(method, exception, exchange_name='N/A', queue_name='N/A')
			"#{log_prefix}.#{method} Exception on exch: #{exchange_name} queue: #{queue_name}" +
			" - #{exception.message}\n#{exception.inspect}"
		end
		private_class_method :exception_message

		def self.log_exception_message(*args)
			puts exception_message(*args)
		end

		def self.log_exception(method, e)
			log :error, e.message, method: method, exception: e.inspect unless silent?
		end
		private_class_method :log_exception

		def self.log(level, message, extra = {})
			statement = "component=mbus at=#{level} message=\"#{message}\""
			extra.each do |key, value|
				statement += " #{key}=#{value.to_json}"
			end
			puts statement 
		end

		def self.with_reconnect_on_failure(method, &block)
			retries = 0
			delay = 1
			begin
				yield
			rescue Bunny::ProtocolError, Bunny::ConnectionError => e
				log_exception_message(method, e)
				retries += 1
				if retries <= 6 # will sleep at most 2^6 = 64s before process dies.
					delay <<= 1 # 2^x
					log :info, "Reconnecting after #{delay}s delay (attempt: #{retries})"
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
