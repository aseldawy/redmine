class TimelogFromTo < ActiveRecord::Migration
  def self.up
    add_column :time_entries, :spent_from, :datetime
    add_column :time_entries, :spent_to, :datetime
    add_column :time_entries, :activity_ratio, :integer
    
    TimeEntry.delete_all('hours = 0.0')
    TimeEntry.update_all('spent_from = spent_on')
    TimeEntry.update_all('spent_to=FLOOR(spent_from+Floor(hours)*10000+ ROUND((hours-FLOOR(hours))*60)*100)', 'hours < 24.0 AND hours > 0.0')
    TimeEntry.find(:all, :conditions=>'hours >= 24.0').each do |time_entry|
      time_entry.hours = time_entry.hours
      time_entry.save!
    end
  end

  def self.down
    #TimeEntry.update_all('spent_on=spent_from, hours = HOUR(timediff(spent_to, spent_from)) + MINUTE(timediff(spent_to, spent_from))/60.0')
    
    remove_column :time_entries, :activity_ratio
    remove_column :time_entries, :spent_from
    remove_column :time_entries, :spent_to
  end
end
