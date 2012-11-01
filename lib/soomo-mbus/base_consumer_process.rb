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
			base_initialize(opts)
		end

		def base_initialize(opts={})
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
			if queues_list.size < 1
				@continue_to_process = false
				puts "#{log_prefix}.base_initialize Error - no queues defined for this app name" unless silent?
			else
				unless test_mode?
					Mbus::Io.start
				end
				puts "#{log_prefix}.base_initialize completed" unless silent?
			end
		end

		def initialize_queue_empty_sleep_time
			value = ENV['MBUS_QE_TIME'] ||= '15'
			(value.downcase == 'stop') ? -1 : value.to_i
		end

		def initialize_queues_list
			wrapper_list = []
			Mbus::Config::queues_for_app(app_name).each { | entry |
				wrapper_list << Mbus::QueueWrapper.new(entry)
			}
			wrapper_list
		end

		def initialize_max_sleeps
			value = ENV['MBUS_MAX_SLEEPS'] ||= '-1'
			value.to_i
		end

		def test_mode?
			@options[:test_mode] # presence = truth
		end

		def verbose?
			@options[:verbose] && @options[:verbose] == true
		end

		def silent?
			@options[:silent] && @options[:silent] == true
		end

		def shutdown
			base_shutdown
		end

		def base_shutdown
			puts "#{log_prefix}.base_shutdown starting" unless silent?
			Mbus::Io.shutdown
			puts "#{log_prefix}.base_shutdown completed" unless silent?
		end

		def process_loop
			while continue_to_process
				@continue_to_process = false if test_mode?
				@cycles = cycles + 1
				queues_list.each { | qw |
					if qw.should_read?
						json_msg_str = Mbus::Io.read_message(qw.exch, qw.name)
						if (json_msg_str == :queue_empty) || json_msg_str.nil?
							handle_no_message(qw)
						else
							@messages_read = messages_read + 1
							process_and_ack_message(qw, json_msg_str)
						end
					end
				}
				go_to_sleep('process_loop - cycle queue(s) empty', queue_empty_sleep_time) if should_sleep?
			end
		end

		def should_sleep?
			queues_list.each { | qw | return false if qw.should_read? }
			true
		end

		def go_to_sleep(method, time)
			@sleep_count = sleep_count + 1
			msg = "cycle #{cycles}, sleep # #{sleep_count} for #{time}, mr: #{messages_read}, mp: #{messages_processed}"
			if max_sleeps < 0
				puts "#{log_prefix}.#{method} - #{msg}" unless silent?
				sleep(time)
			else
				if sleep_count >= max_sleeps
					@continue_to_process = false
				else
					puts "#{log_prefix}.#{method} - #{msg}" unless silent?
					sleep(time)
				end
			end
		end

		def handle_no_message(qw)
			qw.next_read_time!(queue_empty_sleep_time)
			if queue_empty_sleep_time < 0
				puts "#{log_prefix}.handle_no_message - no messages; terminating" unless silent?
				@continue_to_process = false
			end
		end

		def process_and_ack_message(qw, json_msg_str)
			begin
				process_message(qw, json_msg_str)
			rescue Exception => e
				puts "#{log_prefix}.process_and_ack_message Exception #{e.class.name} #{e.message}" unless silent?
			ensure
				Mbus::Io.ack_queue(qw.exch, qw.name) if qw.ack?
			end
		end

		def process_message(qw, json_msg_str)
			# Dynamically create and invoke a message handler class.
			# All message hander class names are in the form: OooAaaMessageHandler - where
			# Ooo is the "object" value in the message (i.e. - classname, ex. - 'Student'),
			# and Aaa is the "action" value in the message (ex. - 'created').
			# Message handler classes should extend Mbus::BaseMessageHandler, and implement
			# the "handle(msg_hash)" method, where the arg a message Hash object.
			begin
				puts "#{log_prefix}.process_message: #{json_msg_str.inspect}" if verbose?
				msg_hash = JSON.parse(json_msg_str)
				handler = Object.const_get(handler_classname(msg_hash)).new(options)
				handler.handle(msg_hash)
				@messages_processed = messages_processed + 1
			rescue Exception => e
				puts "#{log_prefix}.process_message Exception exch: #{qw.exch} queue: #{qw.name} #{e.class.name} #{e.message}\n#{e.backtrace}" unless silent?
			end
		end

		def handler_classname(msg_hash)
			if msg_hash && msg_hash.kind_of?(Hash) && (action = msg_hash['action'])
				classname_map[action] ||= classname_from_action(action)
			else
				nil
			end
		end

		def classname_from_action(action)
			result = action.tr('-','_').split('_').map {|token| token.capitalize }.join
			result << "MessageHandler"
			result
		end

		def classname
			self.class.name
		end

		def log_prefix
			"#{app_name} #{classname}"
		end

	end
end
