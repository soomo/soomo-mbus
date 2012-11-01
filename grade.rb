# :markup: tomdoc

# Internal: This class demonstrates the use of the Mbus::Producer mixin.
# Both regular method calls, and ActiveRecord hooks, may cause messages
# to be put on the bus via the 'mbus_enqueue' method of Mbus::Producer.
#
# create_table :grades do | g |
#   g.integer :student_id,  :null => false
#   g.integer :course_id,   :null => false
#   g.integer :grade_value, :null => false
#   g.timestamps
# end
#
# Chris Joakim, Locomotive LLC, for Soomo Publishing, 2012/02/23

class Grade < ActiveRecord::Base

	include Mbus::Producer

	after_create  { mbus_enqueue(self, 'create') }
	after_update  { mbus_enqueue(self, 'update') }
	after_destroy { mbus_enqueue(self, 'destroy') }

	def miscalculate
		begin
			1 / 0
		rescue Exception => e
			mbus_enqueue(self, 'exception')
		end
	end
end

