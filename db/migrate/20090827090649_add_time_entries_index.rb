class AddTimeEntriesIndex < ActiveRecord::Migration
  def self.up
    add_index :time_entries, [:project_id, :user_id, :issue_id, :spent_on], :name=>'time_entries_merge_index'
  end

  def self.down
    remove_index :time_entries, :name=>'time_entries_merge_index'
  end
end
