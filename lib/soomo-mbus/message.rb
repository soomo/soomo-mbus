module Mbus
	class Message

		def initialize(queue, payload, config = {})
			@queue = queue
			@payload = payload
			@config = config
		end

		attr_reader :queue, :payload

		def requires_acknowledgement?
			@config[:ack]
		end

	end
end
