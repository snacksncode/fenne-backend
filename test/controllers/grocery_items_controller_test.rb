require "test_helper"

class GroceryItemsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get grocery_items_index_url
    assert_response :success
  end
end
