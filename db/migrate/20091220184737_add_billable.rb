class AddBillable < ActiveRecord::Migration
  def self.up
    add_column :issues, :billable, :boolean
    Issue.reset_column_information
    Project.reset_column_information
    billable_custom_field = CustomField.find_by_name("Billable")
    if billable_custom_field
      Issue.find(:all).each do |i|
        i.custom_field_values.each do |custom_field_value|
          if custom_field_value.custom_field == billable_custom_field
            i.billable = custom_field_value.value == "1"
            i.save!
          end
        end
      end
      billable_custom_field.destroy
    end
  end

  def self.down
    remove_column :issues, :billable
  end
end
