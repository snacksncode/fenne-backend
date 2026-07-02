class ProductSearchIndex
  SEARCH_POOL_LIMIT = 30
  SEARCH_RESULT_LIMIT = 10

  class << self
    def search(query:, family:, context:)
      fts_query = build_fts_query(query)
      return [] if fts_query.blank?

      rows = search_rows(fts_query:, query:, family:, context:)
      hydrate(rows, family:)
        .reject { |result| duplicate_suggestion?(result, family) }
        .first(SEARCH_RESULT_LIMIT)
    end

    def upsert_product(product)
      delete("product", product.id)
      insert(
        source_type: "product",
        source_id: product.id,
        family_id: product.family_id,
        name: product.name,
        aisle: Product.aisles.fetch(product.aisle),
        is_kitchen_basic: product.is_kitchen_basic ? 1 : 0
      )
    end

    def upsert_suggestion(suggestion)
      delete("suggestion", suggestion.id)
      insert(
        source_type: "suggestion",
        source_id: suggestion.id,
        family_id: nil,
        name: suggestion.name,
        aisle: ProductSuggestion.aisles.fetch(suggestion.aisle),
        is_kitchen_basic: 0
      )
    end

    def delete(source_type, source_id)
      connection.execute(
        sanitize([ "DELETE FROM product_search_entries WHERE source_type = ? AND source_id = ?", source_type, source_id ])
      )
    end

    def exact_product_exists?(query, family:, context:)
      scope = family.products
      scope = scope.where(is_kitchen_basic: false) if context == "pantry"
      scope.where("LOWER(TRIM(name)) = ?", normalize(query)).exists?
    end

    def exact_suggestion_exists?(query)
      ProductSuggestion.where("LOWER(TRIM(name)) = ?", normalize(query)).exists?
    end

    def add_available?(query, family:, context:)
      return false if context == "pantry"

      !exact_product_exists?(query, family:, context:) && !exact_suggestion_exists?(query)
    end

    private

    def search_rows(fts_query:, query:, family:, context:)
      excludes_kitchen_basics = context == "pantry" ? 1 : 0
      includes_suggestions = context == "pantry" ? 0 : 1
      normalized_query = normalize(query)

      connection.select_all(
        sanitize([
          <<~SQL.squish,
            SELECT source_type, source_id, bm25(product_search_entries) AS fts_rank, name
            FROM product_search_entries
            WHERE product_search_entries MATCH ?
              AND ((? = 1 AND source_type = 'suggestion') OR family_id = ?)
              AND (? = 0 OR source_type != 'product' OR is_kitchen_basic = 0)
            ORDER BY
              CASE WHEN LOWER(name) = ? THEN 0 ELSE 1 END,
              CASE WHEN LOWER(name) LIKE ? THEN 0 ELSE 1 END,
              CASE WHEN LOWER(name) LIKE ? THEN LENGTH(name) ELSE 999999 END,
              fts_rank,
              LENGTH(name),
              LOWER(name)
            LIMIT ?
          SQL
          fts_query,
          includes_suggestions,
          family.id,
          excludes_kitchen_basics,
          normalized_query,
          "#{normalized_query}%",
          "#{normalized_query}%",
          SEARCH_POOL_LIMIT
        ])
      ).to_a
    end

    def hydrate(rows, family:)
      product_ids = rows.filter_map { |row| row["source_id"] if row["source_type"] == "product" }
      suggestion_ids = rows.filter_map { |row| row["source_id"] if row["source_type"] == "suggestion" }
      products_by_id = family.products.where(id: product_ids).index_by { |product| product.id.to_s }
      suggestions_by_id = ProductSuggestion.where(id: suggestion_ids).index_by { |suggestion| suggestion.id.to_s }

      rows.filter_map do |row|
        if row["source_type"] == "product"
          product = products_by_id[row["source_id"].to_s]
          { type: :product, record: product } if product
        else
          suggestion = suggestions_by_id[row["source_id"].to_s]
          { type: :suggestion, record: suggestion } if suggestion
        end
      end
    end

    def duplicate_suggestion?(result, family)
      return false unless result[:type] == :suggestion

      family.products.where("LOWER(TRIM(name)) = ?", normalize(result[:record].name)).exists?
    end

    def insert(source_type:, source_id:, family_id:, name:, aisle:, is_kitchen_basic:)
      connection.execute(
        sanitize([
          <<~SQL.squish,
            INSERT INTO product_search_entries(source_type, source_id, family_id, name, aisle, is_kitchen_basic)
            VALUES (?, ?, ?, ?, ?, ?)
          SQL
          source_type,
          source_id,
          family_id,
          name,
          aisle,
          is_kitchen_basic
        ])
      )
    end

    def build_fts_query(query)
      query.to_s.downcase.scan(/[[:alnum:]]+/).map { |token| "#{token}*" }.join(" ")
    end

    def normalize(value)
      value.to_s.strip.downcase
    end

    def connection
      ActiveRecord::Base.connection
    end

    def sanitize(sql)
      ActiveRecord::Base.sanitize_sql_array(sql)
    end
  end
end
