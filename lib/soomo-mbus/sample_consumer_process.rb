module Mbus

	# :markup: tomdoc
	#
	# Public: This is an sample working subclass of Mbus::BaseConsumerProcess.
	# It simply logs the messages that it reads from its configured exchange
	# and queue.
	#
	# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/03/02

	class SampleConsumerProcess < Mbus::BaseConsumerProcess
	end

end
