module Mbus

	# :markup: tomdoc
	#
	# Internal: This class wrappers both an queue entry per the JSON
	# configuration, as well as the corresponding Bunny queue object.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class QueueWrapper

		attr_accessor :config_entry, :queue, :next_read_time

		def initialize(entry={})
			@config_entry, @next_read_time = entry, 0
		end

		def exch
			config_entry['exch']
		end

		def name
			config_entry['name']
		end

		def fullname
			"#{exch}|#{name}"
		end

		def key
			config_entry['key']
		end

		def is_exchange?(exch_name)
			exch_name.to_s == exch
		end

		def ack?
			config_entry['ack']
		end

		def durable?
			config_entry['durable']
		end

		def nowait?
			true
		end

		def next_read_time!(diff=0)
			@next_read_time = (Time.now.to_i) + (diff.to_i)
		end

		def should_read?
			(Time.now.to_i) >= next_read_time
		end

		def next_message
			delivery_info, properties, payload = queue.pop(:ack => ack?, :nowait => nowait?)

			if payload
				Message.new(queue, delivery_info, properties, payload, ack: ack?)
			else
				:queue_empty
			end
		end
	end

end
