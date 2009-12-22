# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class TimeEntry < ActiveRecord::Base
  # could have used polymorphic association
  # project association here allows easy loading of time entries at project level with one database trip
  belongs_to :project
  belongs_to :issue
  belongs_to :user
  belongs_to :activity, :class_name => 'TimeEntryActivity', :foreign_key => 'activity_id'
  
  attr_protected :project_id, :user_id, :tyear, :tmonth, :tweek

  acts_as_customizable
  acts_as_event :title => Proc.new {|o| "#{l_hours(o.hours)} (#{(o.issue || o.project).event_title})"},
                :url => Proc.new {|o| {:controller => 'timelog', :action => 'details', :project_id => o.project, :issue_id => o.issue}},
                :author => :user,
                :description => :comments

  acts_as_activity_provider :timestamp => "#{table_name}.created_on",
                            :author_key => :user_id,
                            :find_options => {:include => :project} 

  validates_presence_of :user_id, :activity_id, :project_id, :hours, :spent_on, :spent_from, :spent_to
  validates_numericality_of :hours, :allow_nil => true, :message => :invalid
  validates_length_of :comments, :maximum => 255, :allow_nil => true
  
  before_validation :merge_entries

  def after_initialize
    if new_record? && self.activity.nil?
      if default_activity = TimeEntryActivity.default
        self.activity_id = default_activity.id
      end
    end
  end
  
  def before_validation
    self.project = issue.project if issue && project.nil?
    if (spent_from && spent_to)
      self.hours = (spent_to - spent_from)/60.0/60.0 if spent_to - spent_from > 0
      self.spent_on = self.spent_from
    end
  end
  
  def validate
    errors.add :hours, :invalid if hours && (hours < 0 || hours >= 1000)
    errors.add :project_id, :invalid if project.nil?
    errors.add :issue_id, :invalid if (issue_id && !issue) || (issue && project!=issue.project)
  end
  
  def hours=(h)
    write_attribute :hours, (h.is_a?(String) ? (h.to_hours || h) : h)
    self.spent_to = self.spent_from.advance(:hours=>hours) if self.spent_from && hours
  end
  
  # tyear, tmonth, tweek assigned where setting spent_on attributes
  # these attributes make time aggregations easier
  def spent_on=(date)
    super
    self.tyear = spent_on ? spent_on.year : nil
    self.tmonth = spent_on ? spent_on.month : nil
    self.tweek = spent_on ? Date.civil(spent_on.year, spent_on.month, spent_on.day).cweek : nil
    self.spent_from = date
    self.spent_to = self.spent_from.advance(:hours=>hours) if self.spent_from && hours
  end
  
  # Returns true if the time entry can be edited by usr, otherwise false
  def editable_by?(usr)
    (usr == user && usr.allowed_to?(:edit_own_time_entries, project)) || usr.allowed_to?(:edit_time_entries, project)
  end
  
  def self.visible_by(usr)
    with_scope(:find => { :conditions => Project.allowed_to_condition(usr, :view_time_entries) }) do
      yield
    end
  end

  def billable?
    issue && issue.billable
  end
  
  def image=(value)
    @image = value
  end
  
  def after_save
    if @image
      File.open(image_file_name, "wb") do |f|
        f.write @image.read
      end        
    end
  end
  
  def image
    if !@image
      File.open(image_file_name) do |f|
        @image = f.read
      end
    end
    @image
  end
  
  protected
  def image_file_name
    File.join(USER_IMAGES_DIR,id.to_s+".gif")
  end
  
  # Merge adjacent time entries on new
  def merge_entries
    # Find a time entry that could be adjacent
    t = nil
    begin
      t = TimeEntry.find(:last, :conditions=>['id <> :id  AND project_id=:project_id AND user_id=:user_id AND issue_id=:issue_id AND
            (comments=:comments OR (comments is null and :comments is null)) AND activity_id=:activity_id AND spent_on=:spent_on AND
            (spent_to BETWEEN :s1 AND :e1  OR :start1 BETWEEN SUBTIME(spent_from,MAKETIME(0,2,0)) AND ADDTIME(spent_to,MAKETIME(0,2,0)))',
          {:id=>self.id || 0, :project_id=>self.project_id, :user_id=>self.user_id, :issue_id=>self.issue_id,
          :comments=>self.comments, :activity_id=>self.activity_id, :spent_on=>self.spent_from.to_date,
          :s1=>self.spent_from-2.minutes, :e1=>self.spent_to+2.minutes,
          :start1=>self.spent_from}])
      return unless t
      self.spent_from = t.spent_from if t.spent_from < self.spent_from
      self.spent_to = t.spent_to if t.spent_to > self.spent_to
      # no longer need that entry
      t.destroy
    end while t
  end
end
