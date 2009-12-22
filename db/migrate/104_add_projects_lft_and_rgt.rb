class AddProjectsLftAndRgt < ActiveRecord::Migration
  def self.up
    add_column :projects, :lft, :integer
    add_column :projects, :rgt, :integer
    # set all projects as root
    # TODO get correct information from parent_id
    Project.update_all("lft=id, rgt=id")
  end

  def self.down
    remove_column :projects, :lft
    remove_column :projects, :rgt
  end
end
