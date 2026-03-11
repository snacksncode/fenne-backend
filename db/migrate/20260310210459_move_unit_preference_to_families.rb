class MoveUnitPreferenceToFamilies < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :unit_preference, :integer
    add_column :families, :unit_preference, :integer, default: 0, null: false
  end
end
