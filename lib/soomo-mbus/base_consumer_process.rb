module Mbus

	# :markup: tomdoc
	#
	# Internal: This class is intended to be used "as-is" for any process which
	# consumes messages from the message bus.  It may also be subclassed.
	# It provides basic redis (configuration) and rabbitmq connectivity.
	# It also provides a standard run-loop for processing messages; the loop
	# includes message-handler creation and message ack logic.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class BaseConsumerProcess

		attr_reader :options, :app_name, :continue_to_process, :cycles
		attr_reader :queues_list, :messages_read, :messages_processed, :classname_map
		attr_reader :sleep_count, :max_sleeps
		attr_reader :queue_empty_sleep_time

		def initialize(opts={})
			@options  = opts
			@app_name = ENV['MBUS_APP']
			Mbus::Io.initialize(app_name, options)
			@continue_to_process      = true
			@cycles                   = 0
			@messages_read            = 0
			@messages_processed       = 0
			@sleep_count              = 0
			@classname_map            = {}
			@queue_empty_sleep_time   = initialize_queue_empty_sleep_time
			@queues_list              = initialize_queues_list
			@max_sleeps               = initialize_max_sleeps
			if queues_list.empty?
				@continue_to_process = false
				logger.info "Error - no queues defined for this app name"
			else
				unless test_mode?
					exit unless Mbus::Io.start
				end
				logger.info "completed"
			end
		end

		def initialize_queue_empty_sleep_time
			value = ENV['MBUS_QE_TIME'] ||= '15'
			(value.downcase == 'stop') ? -1 : value.to_i
		end

		def initialize_queues_list
			Mbus::Config.queues_for_app(app_name).map do |entry|
				Mbus::QueueWrapper.new(entry)
			end
		end

		def initialize_max_sleeps
			value = ENV['MBUS_MAX_SLEEPS'] ||= '-1'
			value.to_i
		end

		def test_mode?
			@options[:test_mode] # presence = truth
		end

		def shutdown
			logger.info "starting"
			Mbus::Io.shutdown
			logger.info "completed"
		end

		def process_loop
			%w(INT TERM).each do |signal|
				Signal.trap(signal) { $shutdown = true }
			end

			while continue_to_process
				return if $shutdown # handle trapped signal

				@continue_to_process = false if test_mode?
				go_to_sleep('process_loop - delay', options[:delay]) if options[:delay]

				@cycles = cycles + 1
				queues_list.each do |queue|
					if queue.should_read?
						serialized_message = Mbus::Io.read_message(queue.exch, queue.name)
						if (serialized_message == :queue_empty) || serialized_message.nil?
							handle_no_message(queue)
						else
							@messages_read = messages_read + 1
							process_and_ack_message(queue, serialized_message)
						end
					end
				end
				go_to_sleep('process_loop - cycle queue(s) empty', queue_empty_sleep_time) if should_sleep?
			end
		end

		def should_sleep?
			queues_list.each { |q| return false if q.should_read? }
			true
		end

		def go_to_sleep(method, time)
			@sleep_count = sleep_count + 1
			msg = "cycle #{cycles}, sleep # #{sleep_count} for #{time}, mr: #{messages_read}, mp: #{messages_processed}"
			if max_sleeps < 0
				logger.info "#{method} - #{msg}"
				n_second_sleep(time)
			else
				if sleep_count >= max_sleeps
					@continue_to_process = false
				else
					logger.info "#{method} - #{msg}"
					n_second_sleep(time)
				end
			end
		end

		# Allow us to break out of sleep if TERM received
		def n_second_sleep(n)
			n.times do
				sleep 1
				break if $shutdown
			end
		end

		def handle_no_message(queue)
			queue.next_read_time!(queue_empty_sleep_time)
			if queue_empty_sleep_time < 0
				logger.info "- no messages; terminating"
				@continue_to_process = false
			end
		end

		def process_and_ack_message(queue, serialized_message)
			success = process_message(queue, serialized_message)

			if queue.ack?
				if success
					Mbus::Io.ack_queue(queue.exch, queue.name)
				else
					logger.info "Failed to process message and ACK required. Exiting.."
					@continue_to_process = false
					Signal.trap('EXIT') { exit 1 } # force non-success exit
				end
			end
		end

		def process_message(queue, serialized_message)
			# Dynamically create and invoke a message handler class.
			# All message hander class names are in the form: OooAaaMessageHandler - where
			# Ooo is the "object" value in the message (i.e. - classname, ex. - 'Student'),
			# and Aaa is the "action" value in the message (ex. - 'created').
			# Message handler classes should extend Mbus::BaseMessageHandler, and implement
			# the "handle(msg_hash)" method, where the arg a message Hash object.
			begin
				logger.debug serialized_message.inspect

				message_hash = JSON.parse(serialized_message)
				handler = handler_for_action(message_hash['action'])
				handler.handle(message_hash)

				@messages_processed = messages_processed + 1
				success = true
			rescue Exception => e
				success = false
				logger.error "Exception exch: #{queue.exch} queue: #{queue.name} #{e.class.name} #{e.message}\n#{e.backtrace.join("\n")}"
			end

			return success
		end

		def handler_for_action(action)
			Object.const_get(classname_from_action(action)).new(options)
		end

		def classname_from_action(action)
			unless classname = classname_map[action]
				classname = action.tr('-','_').split('_').map {|token| token.capitalize }.join
				classname << "MessageHandler"
				classname_map[action] = classname
			end
			return classname
		end

		class Logger
			attr_reader :base

			def initialize(base)
				@base = base
				if defined?(::Rails)
					@logger = ::Rails.logger
				else
					@logger = ::Logger.new(STDOUT)
					if silent?
						@logger.level = ::Logger::WARN
					elsif verbose?
						@logger.level = ::Logger::DEBUG
					else
						@logger.level = ::Logger::INFO
					end
				end
			end

			def silent?
				base.options[:silent] == true
			end

			def verbose?
				base.options[:verbose] == true
			end

			%w(debug info warn error fatal).each do |severity|
				define_method(severity) do |message|
					method = (caller[0] =~ /`(.*?)'/) && $1
					@logger.send(severity, "#{base.app_name} #{base.class.name}.#{method} #{message}")
				end
			end
		end

		def logger
			@logger ||= Logger.new(self)
		end

	end
end
