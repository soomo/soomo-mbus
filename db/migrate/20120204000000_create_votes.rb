class CreateVotes < ActiveRecord::Migration
  
  def self.up
    create_table :votes do |t|
      t.string :voter_name,     :null => false, :limit => 128
      t.string :candidate_name, :null => false, :limit => 128
      t.timestamps
    end
    add_index :votes, :candidate_name
  end

  def self.down
    drop_table :votes
  end
end
