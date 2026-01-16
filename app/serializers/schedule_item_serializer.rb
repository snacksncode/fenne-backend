class ScheduleItemSerializer
  def self.render(schedule_item)
    if schedule_item.kind_recipe?
      {
        id: schedule_item.id.to_s,
        type: :recipe,
        recipe: RecipeSerializer.render(schedule_item.recipe)
      }
    else
      {
        id: schedule_item.id.to_s,
        type: :dining_out,
        name: schedule_item.dining_out_name
      }
    end
  end
end
