class ScheduleDaySerializer
  def self.render(day)
    {
      date: day.date.to_s,
      breakfast: day.breakfast.present? ? ScheduleItemSerializer.render(day.breakfast) : nil,
      lunch: day.lunch.present? ? ScheduleItemSerializer.render(day.lunch) : nil,
      dinner: day.dinner.present? ? ScheduleItemSerializer.render(day.dinner) : nil,
      is_shopping_day: day.is_shopping_day
    }
  end

  def self.render_many(days)
    days.map { |day| render(day) }
  end
end
