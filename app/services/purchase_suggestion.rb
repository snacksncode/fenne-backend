# Exact recipe quantities enter here in the tracking unit. Only purchases are rounded.
class PurchaseSuggestion
  def self.call(product:, needed:, pantry: nil)
    pantry ||= product.pantry_entries.sum(&:quantity_remaining)
    shortage = [needed.to_d - pantry.to_d, 0.to_d].max
    shortage = shortage.ceil.to_d if product.counted?
    packs = product.measured? ? Array(product.pack_sizes) : []
    quantities = packs.map { |size| (size.to_d * 1000).round.to_i }.uniq.sort.reverse
    selection = quantities.empty? || shortage.zero? ? {} : best_packs(quantities, (shortage * 1000).ceil)
    total = selection.empty? ? shortage : selection.sum { |size, count| size * count }.to_d / 1000
    {
      needed: needed.to_f, pantry: pantry.to_f, shortage: shortage.to_f,
      suggested_quantity: total.to_f,
      packs: selection.sort.reverse.map { |size, count| { size: size / 1000.0, count: count } }
    }
  end

  # Enumerate larger packs first, pruning totals that cannot improve the best purchase.
  # Scale by the common divisor so equivalent units produce the same result.
  def self.best_packs(sizes, target)
    divisor = sizes.reduce(&:gcd)
    sizes = sizes.map { |size| size / divisor }
    target = (target.to_d / divisor).ceil
    best = { sizes.first => (target.to_d / sizes.first).ceil }
    best_total = best.sum { |size, count| size * count }
    best_count = best.values.sum
    visit = lambda do |index, remaining, chosen, count|
      size = sizes[index]
      maximum = (remaining.to_d / size).ceil
      maximum.downto(0) do |amount|
        total_count = count + amount
        rest = remaining - size * amount
        if rest <= 0
          total = target - rest
          if total < best_total || (total == best_total && total_count < best_count)
            best = chosen.merge(size => amount).reject { |_, n| n.zero? }
            best_total, best_count = total, total_count
          end
        elsif index + 1 < sizes.length
          next if best_total == target && total_count + (rest.to_d / sizes[index + 1]).ceil >= best_count
          visit.call(index + 1, rest, chosen.merge(size => amount), total_count)
        end
        break if index == sizes.length - 1
      end
    end
    visit.call(0, target, {}, 0)
    best.transform_keys { |size| size * divisor }
  end
  private_class_method :best_packs
end
