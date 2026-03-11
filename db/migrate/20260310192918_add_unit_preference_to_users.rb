class AddUnitPreferenceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :unit_preference, :integer, default: 0, null: false
  end
end
