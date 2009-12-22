# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

module TimelogHelper
  include ApplicationHelper
  
  def render_timelog_breadcrumb
    links = []
    links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})
    links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project
    if @issue
      if @issue.visible?
        links << link_to_issue(@issue, :subject => false)
      else
        links << "##{@issue.id}"
      end
    end
    breadcrumb links
  end

  # Returns a collection of activities for a select field.  time_entry
  # is optional and will be used to check if the selected TimeEntryActivity
  # is active.
  def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= @project
    if project.nil?
      activities = TimeEntryActivity.shared.active
    else
      activities = project.activities
    end

    collection = []
    if time_entry && time_entry.activity && !time_entry.activity.active?
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
    else
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
    end
    activities.each { |a| collection << [a.name, a.id] }
    collection
  end
  
  def select_hours(data, criteria, value, billable=nil)
  	if value.to_s.empty?
  		data = data.select {|row| row[criteria].blank? }
    else 
    	data = data.select {|row| row[criteria] == value}
    end
    if billable != nil
      data = data.select {|row| row["billable"] == billable}
    end
    data
  end
  
  def sum_hours(data)
    sum = 0
    data.each do |row|
      sum += row['hours'].to_f
    end
    sum
  end
  
  def ratio_color(ratio)
    red_component = (1-ratio) * 255
    green_component = (ratio) * 128
    "#%02x%02x%02x" % [red_component, green_component, 0]
  end
  
  def options_for_period_select(value)
    options_for_select([[l(:label_all_time), 'all'],
                        [l(:label_today), 'today'],
                        [l(:label_yesterday), 'yesterday'],
                        [l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_last_n_days, 7), '7_days'],
                        [l(:label_this_month), 'current_month'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_last_n_days, 30), '30_days'],
                        [l(:label_this_year), 'current_year']],
                        value)
  end
  
  def entries_to_csv(entries)
    ic = Iconv.new(l(:general_csv_encoding), 'UTF-8')    
    decimal_separator = l(:general_csv_decimal_separator)
    custom_fields = TimeEntryCustomField.find(:all)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [l(:field_spent_on),
                 l(:field_user),
                 l(:field_activity),
                 l(:field_project),
                 l(:field_issue),
                 l(:field_tracker),
                 l(:field_subject),
                 l(:field_hours),
                 l(:field_comments)
                 ]
      # Export custom fields
      headers += custom_fields.collect(&:name)
      
      csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      # csv lines
      entries.each do |entry|
        fields = [format_date(entry.spent_on),
                  entry.user,
                  entry.activity,
                  entry.project,
                  (entry.issue ? entry.issue.id : nil),
                  (entry.issue ? entry.issue.tracker : nil),
                  (entry.issue ? entry.issue.subject : nil),
                  entry.hours.to_s.gsub('.', decimal_separator),
                  entry.comments
                  ]
        fields += custom_fields.collect {|f| show_value(entry.custom_value_for(f)) }
                  
        csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      end
    end
    export
  end
  
  def format_criteria_value(criteria, value)
    if value.blank?
      l(:label_none)
    elsif k = @available_criterias[criteria][:klass]
      obj = k.find_by_id(value.to_i)
      if obj.is_a?(Issue)
        obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
      else
        obj
      end
    else
      format_value(value, @available_criterias[criteria][:format])
    end
  end
  
  def report_to_csv(criterias, periods, hours)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # Column headers
      headers = criterias.collect {|criteria| l(@available_criterias[criteria][:label]) }
      headers += periods
      headers << l(:label_total)
      csv << headers.collect {|c| to_utf8(c) }
      # Content
      report_criteria_to_csv(csv, criterias, periods, hours)
      # Total row
      row = [ l(:label_total) ] + [''] * (criterias.size - 1)
      total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours, @columns, period.to_s))
        total += sum
        row << (sum > 0 ? "%.2f" % sum : '')
      end
      row << "%.2f" %total
      csv << row
    end
    export
  end
  
  def report_criteria_to_csv(csv, criterias, periods, hours, level=0)
    hours.collect {|h| h[criterias[level]].to_s}.uniq.each do |value|
      hours_for_value = select_hours(hours, criterias[level], value)
      next if hours_for_value.empty?
      row = [''] * level
      row << to_utf8(format_criteria_value(criterias[level], value))
      row += [''] * (criterias.length - level - 1)
      total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours_for_value, @columns, period.to_s))
        total += sum
        row << (sum > 0 ? "%.2f" % sum : '')
      end
      row << "%.2f" %total
      csv << row
      
      if criterias.length > level + 1
        report_criteria_to_csv(csv, criterias, periods, hours_for_value, level + 1)
      end
    end
  end
  
  def to_utf8(s)
    @ic ||= Iconv.new(l(:general_csv_encoding), 'UTF-8')
    begin; @ic.iconv(s.to_s); rescue; s.to_s; end
  end
  
  def url_for_time_details(hours_for_value, criterias, level, value, periods_time, period_i, options={})
    url_hash = {:controller=>'timelog', :action=>'report' }
    # add select for criteria
    url_hash[:criterias] = criterias
    0.upto(level) do |i|
      if hours_for_value[0][criterias[i]]
        if criterias[i] == "member"
          url_hash[:user_id] = hours_for_value[0][criterias[i]]
        elsif criterias[i] == "issue"
          url_hash[:issue_id] = hours_for_value[0][criterias[i]]
          url_hash[:project_id] = Issue.find(hours_for_value[0][criterias[i]]).project
        end
      end
    end
    
    # add select for date
    url_hash.update({:period=>'all', :period_type=>2 })
    url_hash[:from] = periods_time[period_i][:date_from].strftime("%Y-%m-%d")
    url_hash[:to] = periods_time[period_i][:date_to].strftime("%Y-%m-%d")
    
    # update with options
    url_hash.update(options)
    url_for url_hash
  end
  
  def time_entry_color(time_entry)
    "##{time_entry.issue.color}"
  end
  
  def time_entry_title(time_entry)
    "[#{html_hours(time_entry.hours)}] #{time_entry.project.name}/#{time_entry.issue.subject}(#{time_entry.comments})"
  end

  def time_entry_width(hours, scale, border = 0)
    if hours.is_a? TimeEntry
      hours = hours.hours
    end
    width = hours  * scale - border * 2
    width = 0 if width < 0
    "#{width}px"
  end
  
  def time_entry_div(time_entry, options)
    %{<div class="entry #{time_entry.issue.css_classes}" title="#{time_entry_title(time_entry)}"
      style="background-color: #{time_entry_color(time_entry)}; width: #{time_entry_width(time_entry, options[:scale], 1)}; border: solid 1px;">
      #{time_entry_title(time_entry)}</div>}
  end
  
  def empty_div(hours, text, options)
    options[:border] ||= 0
    %{<div class="entry" style="width: #{time_entry_width(hours, options[:scale], options[:border])}; #{options[:style]}">#{text}</div>}
  end
end
