require "test_helper"

class QueryInvalidatorTest < ActiveSupport::TestCase
  test "broadcast sends message to family stream" do
    family = families(:smith_family)

    assert_broadcasts("family_invalidation_stream_#{family.id}", 1) do
      QueryInvalidator.broadcast("recipes", family, {id: 123})
    end
  end

  test "broadcast includes resource and data" do
    family = families(:smith_family)
    expected_data = {id: 456, name: "Test Recipe"}

    assert_broadcast_on("family_invalidation_stream_#{family.id}", {resource: "recipes", data: expected_data}) do
      QueryInvalidator.broadcast("recipes", family, expected_data)
    end
  end

  test "broadcast works with nil data" do
    family = families(:smith_family)

    assert_broadcast_on("family_invalidation_stream_#{family.id}", {resource: "grocery_items", data: nil}) do
      QueryInvalidator.broadcast("grocery_items", family, nil)
    end
  end

  test "broadcast handles different resource types" do
    family = families(:smith_family)

    ["recipes", "grocery_items", "schedule", "invitations"].each do |resource|
      assert_broadcast_on("family_invalidation_stream_#{family.id}", {resource: resource, data: nil}) do
        QueryInvalidator.broadcast(resource, family)
      end
    end
  end
end
