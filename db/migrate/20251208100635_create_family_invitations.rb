class CreateFamilyInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :family_invitations do |t|
      t.references :family, null: false, foreign_key: true
      t.references :from_user, null: false, foreign_key: {to_table: :users}
      t.references :to_user, null: false, foreign_key: {to_table: :users}

      t.timestamps
    end
  end
end
