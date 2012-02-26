class CreateGrades < ActiveRecord::Migration

  def self.up
    create_table :grades do | g |
      g.integer :student_id,  :null => false
      g.integer :course_id,   :null => false
      g.integer :grade_value, :null => false
      g.timestamps
    end
  end

  def self.down
    drop_table :grades
  end
end
