class MakeIssuesUsersManyToMany < ActiveRecord::Migration
  def self.up
    # Create many to many table
    create_table :issues_users, :id=>false do |t|
      t.integer :issue_id
      t.integer :user_id
    end
    
    # Initialize it with current data
    connection.insert_sql "insert into issues_users(issue_id, user_id) " +
      "select id, assigned_to_id from issues"
    
    remove_column :issues, :assigned_to_id
  end

  def self.down
    add_column :issues, :assigned_to_id, :integer

    # Initialize it with current data (use first assigned person only)
    connection.update_sql "update issues set assigned_to_id = (select user_id from issues_users where issue_id = issues.id limit 1)"

    drop_table :issues_users
  end
end
