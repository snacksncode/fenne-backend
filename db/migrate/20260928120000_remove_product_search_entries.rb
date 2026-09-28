class RemoveProductSearchEntries < ActiveRecord::Migration[8.0]
  def down
    create_virtual_table :product_search_entries, :fts5, [
      "source_type UNINDEXED",
      "source_id UNINDEXED",
      "family_id UNINDEXED",
      "name",
      "aisle UNINDEXED",
      "is_kitchen_basic UNINDEXED",
      "tokenize = 'unicode61'",
      "prefix = '2 3 4'"
    ]

    execute <<~SQL
      INSERT INTO product_search_entries(source_type, source_id, family_id, name, aisle, is_kitchen_basic)
      SELECT 'product', id, family_id, name, aisle, is_kitchen_basic
      FROM products
    SQL

    execute <<~SQL
      INSERT INTO product_search_entries(source_type, source_id, family_id, name, aisle, is_kitchen_basic)
      SELECT 'suggestion', id, NULL, name, aisle, 0
      FROM product_suggestions
    SQL
  end

  def up
    drop_virtual_table :product_search_entries, :fts5, []
  end
end
