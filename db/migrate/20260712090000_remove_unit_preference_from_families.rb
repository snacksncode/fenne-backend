class RemoveUnitPreferenceFromFamilies < ActiveRecord::Migration[8.0]
  def change
    remove_column :families, :unit_preference, :integer
  end
end
