namespace :redmine do
  task :migrate_db => :environment do
	# delete old database
  puts "Deleting old database"
	`mysqladmin -u root -pnightmare --force drop redmine_development`
	
	# Recreate database
  puts "Creating new database"
	`mysqladmin -u root -pnightmare create redmine_development`
	
	# Migrate till version 58 (like old one)
  puts "migrating till version 58"
  ENV['VERSION']= "58"
	Rake::Task['db:migrate'].invoke
	
	# load backup to be migrate
  puts "Loading backup to be mgirated"
	puts `mysql -u redmine redmine_development < redmine_old.sql`
	
	# Migrate till the last version
  Rake::Task['db:migrate'].reenable
  ENV.delete 'VERSION'
  puts "Migrating till the latest version"
	Rake::Task['db:migrate'].invoke ""
	
	# Load roles permissions
  puts "Loading roles permissions"
	load_roles_permissions
	
	# Backup latest database (migrated one)
  puts "Backing up latest database"
	`mysqldump -u redmine redmine_development > redmine_migrated.sql`
  end
  
  def load_roles_permissions
    Role.reset_column_information
	  Role.transaction do
  		# Roles
  		manager = Role.find_by_name("Manager")
  		manager.update_attributes(:position => 1)
  		manager.permissions = manager.setable_permissions.collect {|p| p.name}
  		manager.save!
  
  		developer = Role.find_by_name("Developer")
  		developer.update_attributes(:position => 2, 
  								  :permissions => [:manage_versions, 
  												  :manage_categories,
  												  :add_issues,
  												  :edit_issues,
  												  :manage_issue_relations,
  												  :add_issue_notes,
  												  :save_queries,
  												  :view_gantt,
  												  :view_calendar,
  												  :log_time,
  												  :view_time_entries,
  												  :comment_news,
  												  :view_documents,
  												  :view_wiki_pages,
  												  :view_wiki_edits,
  												  :edit_wiki_pages,
  												  :delete_wiki_pages,
  												  :add_messages,
  												  :edit_own_messages,
  												  :view_files,
  												  :manage_files,
  												  :browse_repository,
  												  :view_changesets,
  												  :commit_access]
  									)
  		reporter = Role.find_by_name("Reporter")
  		reporter.update_attributes(:position => 3,
  								:permissions => [:add_issues,
  												:add_issue_notes,
  												:save_queries,
  												:view_gantt,
  												:view_calendar,
  												:log_time,
  												:view_time_entries,
  												:comment_news,
  												:view_documents,
  												:view_wiki_pages,
  												:view_wiki_edits,
  												:add_messages,
  												:edit_own_messages,
  												:view_files,
  												:browse_repository,
  												:view_changesets])
  					
  		Role.non_member.update_attribute :permissions, [:add_issues,
  														:add_issue_notes,
  														:save_queries,
  														:view_gantt,
  														:view_calendar,
  														:view_time_entries,
  														:comment_news,
  														:view_documents,
  														:view_wiki_pages,
  														:view_wiki_edits,
  														:add_messages,
  														:view_files,
  														:browse_repository,
  														:view_changesets]
  	  
  		Role.anonymous.update_attribute :permissions, [:view_gantt,
  													   :view_calendar,
  													   :view_time_entries,
  													   :view_documents,
  													   :view_wiki_pages,
  													   :view_wiki_edits,
  													   :view_files,
  													   :browse_repository,
  													   :view_changesets]
  	end													 
  end
end