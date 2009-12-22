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

require File.dirname(__FILE__) + '/../test_helper'

class TimeEntryTest < ActiveSupport::TestCase
  fixtures :issues, :projects, :users, :time_entries

  def test_hours_format
    assertions = { "2"      => 2.0,
                   "21.1"   => 21.1,
                   "2,1"    => 2.1,
                   "1,5h"   => 1.5,
                   "7:12"   => 7.2,
                   "10h"    => 10.0,
                   "10 h"   => 10.0,
                   "45m"    => 0.75,
                   "45 m"   => 0.75,
                   "3h15"   => 3.25,
                   "3h 15"  => 3.25,
                   "3 h 15"   => 3.25,
                   "3 h 15m"  => 3.25,
                   "3 h 15 m" => 3.25,
                   "3 hours"  => 3.0,
                   "12min"    => 0.2,
                  }
    
    assertions.each do |k, v|
      t = TimeEntry.new(:hours => k)
      assert_equal v, t.hours, "Converting #{k} failed:"
    end
  end
  
  def test_should_not_merge
    assert_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 04:20', :spent_to=>'2007-03-23 06:30', :comments=>'My hours')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
  end
  
  def test_should_merge_adjacent
    t = nil
    assert_no_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 04:15', :spent_to=>'2007-03-23 06:15', :comments=>'My hours')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
    assert_equal "2007-03-23 00:00", t.spent_from.strftime("%Y-%m-%d %H:%M")
    assert_equal "2007-03-23 06:15", t.spent_to.strftime("%Y-%m-%d %H:%M")
    assert_equal 4.25 + 2, t.hours
  end
  
  def test_should_merge_intersection
    t = nil
    assert_no_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 02:15', :spent_to=>'2007-03-23 06:15', :comments=>'My hours')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
    assert_equal "2007-03-23 00:00", t.spent_from.strftime("%Y-%m-%d %H:%M")
    assert_equal "2007-03-23 06:15", t.spent_to.strftime("%Y-%m-%d %H:%M")
  end
  
  def test_should_merge_completely_contained
    t = nil
    t = TimeEntry.find(1)
    t.spent_from = '2007-03-23 06:15'
    t.spent_to = '2007-03-23 07:15'
    t.save
    assert_no_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 00:00', :spent_to=>'2007-03-23 08:15', :comments=>'My hours')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
    assert_equal "2007-03-23 00:00", t.spent_from.strftime("%Y-%m-%d %H:%M")
    assert_equal "2007-03-23 08:15", t.spent_to.strftime("%Y-%m-%d %H:%M")
  end
  
  def test_should_merge_completely_contains
    t = nil
    assert_no_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 2:15', :spent_to=>'2007-03-23 03:15', :comments=>'My hours')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
    assert_equal "2007-03-23 00:00", t.spent_from.strftime("%Y-%m-%d %H:%M")
    assert_equal "2007-03-23 04:15", t.spent_to.strftime("%Y-%m-%d %H:%M")
  end
  
  def test_should_merge_null_comments
    t = nil
    time_entries(:time_entries_001).update_attributes! :comments=>nil
    assert_no_difference "TimeEntry.count" do
      t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>'2007-03-23 04:15', :spent_to=>'2007-03-23 06:15')
      t.project_id = 1
      t.user_id = 2
      t.save
    end
    assert_equal "2007-03-23 00:00", t.spent_from.strftime("%Y-%m-%d %H:%M")
    assert_equal "2007-03-23 06:15", t.spent_to.strftime("%Y-%m-%d %H:%M")
    assert_equal 4.25 + 2, t.hours
  end
  
  def test_insert_speed
    assert_difference "TimeEntry.count", 1000 do
      1000.times do |i|
        spent_from = 1.year.ago.advance(:days=>i)
        spent_to = spent_from.advance(:hours=>1)
        TimeEntry.connection.insert_sql("INSERT INTO `time_entries` (`spent_to`, `comments`, `project_id`, `issue_id`, `activity_id`, `spent_on`, `user_id`, `spent_from`, `hours`)
         VALUES('#{spent_to.to_s :db}', NULL, 1, 1, 9, '#{spent_from.to_date.to_s :db}', 2, '#{spent_from.to_s :db}', #{1.0/60.0})")
      end
    end
    # Test inserting 10 time entries in less than 3 seconds
    TimeEntry.logger.silence do
      elapsed_time = Benchmark.realtime do
        100.times do |i|
          spent_from = 2.month.ago.advance(:days=>i)
          spent_to = spent_from.advance(:hours=>1)
          t = TimeEntry.new(:activity_id=>9, :issue_id=>1, :spent_from=>spent_from, :spent_to=>spent_to)
          t.project_id = 1
          t.user_id = 2
          t.save
        end
      end
      assert elapsed_time < 3.00, "Elapsed time turn out to be: #{elapsed_time} seconds"
    end
  end

  def test_merge_speed
    assert_difference "TimeEntry.count", 1000 do
      1000.times do |i|
        spent_from = 10.years.ago.advance(:days=>i)
        spent_to = spent_from.advance(:hours=>1)
        TimeEntry.connection.insert_sql("INSERT INTO `time_entries` (`spent_to`, `comments`, `project_id`, `issue_id`, `activity_id`, `spent_on`, `user_id`, `spent_from`, `hours`)
          VALUES('#{spent_to.to_s :db}', NULL, 1, 1, 9, '#{spent_from.to_date.to_s :db}', 2, '#{spent_from.to_s :db}', #{1.0/60.0})")
      end
    end
    assert_difference 'TimeEntry.count', 100 do
      100.times do |i|
        spent_from = 1.year.ago.advance(:minutes=>i)
        spent_to = spent_from.advance(:minutes=>1)
        TimeEntry.connection.insert_sql("INSERT INTO `time_entries` (`spent_to`, `comments`, `project_id`, `issue_id`, `activity_id`, `spent_on`, `user_id`, `spent_from`, `hours`)
           VALUES('#{spent_to.to_s :db}', NULL, 1, 1, 9, '#{spent_from.to_date.to_s :db}', 2, '#{spent_from.to_s :db}', #{1.0/60.0})")
      end
    end
    # Test merging the latest 100 time entries into one
    TimeEntry.logger.silence do
      elapsed_time = Benchmark.realtime do
        assert_difference 'TimeEntry.count', -99 do
          t = TimeEntry.find(:last)
          t.save
        end
      end
      assert elapsed_time < 3.00, "Elapsed time turn out to be: #{elapsed_time} seconds"
    end
  end

  
end
