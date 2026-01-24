require "test_helper"

class SessionTokenTest < ActiveSupport::TestCase
  test "generates token on creation" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)

    assert_not_nil token.token
    assert_equal 64, token.token.length
  end

  test "sets expiration to 90 days from now on creation" do
    user = users(:john_smith)
    freeze_time do
      token = SessionToken.create!(user: user)

      assert_in_delta 90.days.from_now, token.expires_at, 1.second
    end
  end

  test "expired? returns true when token is expired" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)
    token.update!(expires_at: 1.day.ago)

    assert token.expired?
  end

  test "expired? returns false when token is not expired" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)

    assert_not token.expired?
  end

  test "needs_refresh? returns true when less than 60 days remaining" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)
    token.update!(expires_at: 59.days.from_now)

    assert token.needs_refresh?
  end

  test "needs_refresh? returns false when more than 60 days remaining" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)
    token.update!(expires_at: 61.days.from_now)

    assert_not token.needs_refresh?
  end

  test "refresh! extends expiration to 90 days from now" do
    user = users(:john_smith)
    token = SessionToken.create!(user: user)
    token.update!(expires_at: 30.days.from_now)

    freeze_time do
      token.refresh!

      assert_in_delta 90.days.from_now, token.expires_at, 1.second
    end
  end

  test "enforces 5 token limit per user" do
    user = users(:john_smith)
    user.session_tokens.destroy_all

    # Create 5 tokens
    5.times { SessionToken.create!(user: user) }
    assert_equal 5, user.session_tokens.count

    # Creating a 6th token should delete the oldest
    SessionToken.create!(user: user)
    assert_equal 5, user.session_tokens.count
  end

  test "deletes oldest tokens when limit is exceeded" do
    user = users(:john_smith)
    user.session_tokens.destroy_all

    # Create tokens with different created_at times
    oldest_token = nil
    freeze_time do
      oldest_token = SessionToken.create!(user: user)
    end

    travel 1.hour do
      4.times { SessionToken.create!(user: user) }
    end

    travel 2.hours do
      SessionToken.create!(user: user)
    end

    assert_not user.session_tokens.exists?(oldest_token.id)
    assert_equal 5, user.session_tokens.count
  end

  test "belongs to user" do
    token = session_tokens(:john_token_one)

    assert_instance_of User, token.user
    assert_equal users(:john_smith), token.user
  end
end
