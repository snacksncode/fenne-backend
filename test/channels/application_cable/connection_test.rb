require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid token" do
    user = users(:john_smith)
    token = user.session_tokens.first

    connect "/v2/cable?token=#{token.token}"

    assert_equal user.id, connection.user.id
  end

  test "rejects connection with invalid token" do
    assert_reject_connection do
      connect "/v2/cable?token=invalid_token"
    end
  end

  test "rejects connection without token" do
    assert_reject_connection do
      connect "/v2/cable"
    end
  end

  test "identifies connection by user" do
    user = users(:jane_smith)
    token = user.session_tokens.first

    connect "/v2/cable?token=#{token.token}"

    assert_equal user, connection.user
  end

  test "rejects and removes an expired session token" do
    token = users(:john_smith).session_tokens.first
    token.update!(expires_at: 1.minute.ago)

    assert_reject_connection do
      connect "/v2/cable?token=#{token.token}"
    end

    assert_not SessionToken.exists?(token.id)
  end

  test "accepts a valid session token nearing expiration without changing its lifetime" do
    token = users(:john_smith).session_tokens.first
    token.update!(expires_at: 30.days.from_now)

    expires_at = token.expires_at
    connect "/v2/cable?token=#{token.token}"

    assert_equal token.user, connection.user
    assert_equal expires_at, token.reload.expires_at
  end
end
