module Mbus

	# :markup: tomdoc
	#
	# Internal: This class wrappers both an exchange entry per the JSON
	# configuration, as well as the corresponding Bunny exchange object.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class ExchangeWrapper

		attr_accessor :config_entry, :exchange

		def initialize(entry={})
			@config_entry = entry
		end

		def name
			config_entry['name']
		end

		def type
			val = config_entry['type']
			(val.nil?) ? 'topic' : val
		end

		def type_symbol
			type.to_sym
		end

		def persistent?
			val = config_entry['persistent']
			(val.nil?) ? true : val
		end

		def mandatory?
			val = config_entry['mandatory']
			(val.nil?) ? false : val
		end

		def immediate?
			val = config_entry['immediate']
			(val.nil?) ? false : val
		end

		def publish(message, routing_key)
			opts = {
				:key        => routing_key,
				:persistent => persistent?,
				:mandatory  => mandatory?,
				:immediate  => immediate?
			}
			exchange.publish(message, opts)
		end

	end
end
