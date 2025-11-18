class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, index: {unique: true, name: "unique_emails"}
      t.string :password_digest
      t.string :name
      t.timestamps
    end
  end
end
