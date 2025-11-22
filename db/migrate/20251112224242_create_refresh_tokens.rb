class CreateSessionTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :session_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
