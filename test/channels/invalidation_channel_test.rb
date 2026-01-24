require "test_helper"

class InvalidationChannelTest < ActionCable::Channel::TestCase
  test "subscribes to family invalidation stream" do
    test_user = users(:john_smith)

    stub_connection user: test_user
    subscribe

    assert subscription.confirmed?
    assert_has_stream "family_invalidation_stream_#{test_user.family.id}"
  end

  test "receives broadcasts to family stream" do
    test_user = users(:john_smith)

    stub_connection user: test_user
    subscribe

    assert_broadcast_on("family_invalidation_stream_#{test_user.family.id}", {resource: "recipes", data: {id: 1}}) do
      ActionCable.server.broadcast(
        "family_invalidation_stream_#{test_user.family.id}",
        {resource: "recipes", data: {id: 1}}
      )
    end
  end

  test "unsubscribes successfully" do
    test_user = users(:john_smith)

    stub_connection user: test_user
    subscribe
    unsubscribe

    assert_no_streams
  end
end
