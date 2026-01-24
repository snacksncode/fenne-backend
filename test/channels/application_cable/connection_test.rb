require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid token" do
    user = users(:john_smith)
    token = user.session_tokens.first

    connect "/cable?token=#{token.token}"

    assert_equal user.id, connection.user.id
  end

  test "rejects connection with invalid token" do
    assert_reject_connection do
      connect "/cable?token=invalid_token"
    end
  end

  test "rejects connection without token" do
    assert_reject_connection do
      connect "/cable"
    end
  end

  test "identifies connection by user" do
    user = users(:jane_smith)
    token = user.session_tokens.first

    connect "/cable?token=#{token.token}"

    assert_equal user, connection.user
  end
end
