class SearchController < ApplicationController
  def index
    q = params[:q]
    return bad_request!("Missing query string") if q.blank?

    escaped_term = FoodItem.sanitize_sql_like(q)
    items = FoodItem
      .where(family_id: [nil, @current_user.family_id])
      .where("LOWER(name) LIKE ?", "%#{escaped_term}%")
      .order(Arel.sql("CASE WHEN LOWER(name) = '#{escaped_term}' THEN 0 ELSE 1 END"))
      .order(Arel.sql("CASE WHEN LOWER(name) LIKE '#{escaped_term}%' THEN 0 ELSE 1 END"))
      .order(Arel.sql("LENGTH(name) ASC"))
      .limit(10)
    render json: FoodItemSerializer.render_many(items)
  end

  def destroy
    food_item = FoodItem.find(params[:id])
    return bad_request! if food_item.family_id != @current_user.family_id
    food_item.destroy
    render json: {success: true}
  end
end
