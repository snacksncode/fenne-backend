class GroceryListCheckout
  def self.call(family:)
    ApplicationRecord.transaction do
      family.grocery_items.status_completed.detail.order(:id).lock.each do |item|
        product = item.product
        if product && !product.kitchen_basic? && !item.quantity.zero?
          writer = PantryEntryWriter.new(family: family, product: product)
          unless writer.add(quantity_remaining: item.quantity)
            raise ArgumentError, writer.errors.full_messages.to_sentence
          end
        end

        item.finish_checkout!
      end
    end
  end
end
