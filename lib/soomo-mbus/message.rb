module Mbus
	class Message

		def initialize(queue, delivery_info, properties, payload, config = {})
			@queue = queue
			@delivery_info = delivery_info
			@properties = properties
			@payload = payload
			@config = config
		end

		attr_reader :queue, :delivery_info, :properties, :payload

		def requires_acknowledgement?
			@config[:ack]
		end

	end
end
