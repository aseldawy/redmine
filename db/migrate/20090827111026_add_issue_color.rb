class AddIssueColor < ActiveRecord::Migration
  def self.up
    add_column :issues, :color, :string, :default=>'FFFFFF'
  end

  def self.down
    remove_column :issues, :color
  end
end
