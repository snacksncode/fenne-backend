module QueryInvalidation
  extend ActiveSupport::Concern

  private

  def invalidate_family!(family = @current_user.family)
    invalidate_query!(:family, family)
  end

  def invalidate_family_members!(family = @current_user.family)
    invalidate_query!(:family_members, family)
  end

  def invalidate_groceries!(family = @current_user.family)
    invalidate_query!(:grocery_items, family)
  end

  def invalidate_invitations!(family = @current_user.family)
    invalidate_query!(:invitations, family)
  end

  def invalidate_pantry!(family = @current_user.family)
    invalidate_query!(:pantry_entries, family)
  end

  def invalidate_products!(family = @current_user.family)
    invalidate_query!(:products, family)
  end

  def invalidate_recipes!(family = @current_user.family)
    invalidate_query!(:recipes, family)
  end

  def invalidate_schedules!(family = @current_user.family, dates: nil)
    data = dates.present? ? {dates: dates} : nil
    invalidate_query!(:schedules, family, data)
  end

  def invalidate_consumption!(family = @current_user.family)
    invalidate_query!(:consumption_logs, family)
    invalidate_pantry!(family)
  end

  def invalidate_query!(resource, family = @current_user.family, data = nil)
    QueryInvalidator.broadcast(resource, family, data)
  end
end
