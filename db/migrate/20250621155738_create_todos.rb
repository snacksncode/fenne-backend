class CreateTodos < ActiveRecord::Migration[8.0]
  def change
    create_table :todos do |t|
      t.string :content
      t.boolean :is_completed

      t.timestamps
    end
  end
end
