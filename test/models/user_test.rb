require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "auto-creates family on validation if none exists" do
    family_count_before = Family.count
    user = User.new(email: "test@example.com", password: "password123")

    assert_nil user.family_id
    user.validate

    assert_not_nil user.family
    assert_equal family_count_before + 1, Family.count
  end

  test "does not create new family if already assigned" do
    existing_family = families(:smith_family)
    family_count_before = Family.count

    user = User.create!(email: "test@example.com", password: "password123", name: "Test User", family: existing_family)

    assert_equal existing_family, user.family
    assert_equal family_count_before, Family.count
  end

  test "validates email uniqueness" do
    user1 = users(:john_smith)

    user2 = User.new(email: user1.email, password: "password123")

    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  test "allows different emails" do
    user = User.new(email: "unique@example.com", password: "password123")

    assert user.valid?
  end

  test "has secure password" do
    user = User.create!(email: "test@example.com", password: "password123", name: "Test User")

    assert user.authenticate("password123")
    assert_not user.authenticate("wrongpassword")
  end

  test "requires password on creation" do
    user = User.new(email: "test@example.com")

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "has many session tokens" do
    user = users(:john_smith)

    assert_respond_to user, :session_tokens
    assert user.session_tokens.count > 0
  end

  test "destroys session tokens when user is destroyed" do
    user = users(:john_smith)
    token_ids = user.session_tokens.pluck(:id)

    user.destroy

    token_ids.each do |token_id|
      assert_not SessionToken.exists?(token_id)
    end
  end

  test "belongs to family" do
    user = users(:john_smith)

    assert_instance_of Family, user.family
    assert_equal families(:smith_family), user.family
  end

  test "has many sent invitations" do
    user = users(:charlie_wilson)

    assert_respond_to user, :sent_invitations
    assert user.sent_invitations.count > 0
    assert_instance_of FamilyInvitation, user.sent_invitations.first
  end

  test "has many received invitations" do
    user = users(:diana_lee)

    assert_respond_to user, :received_invitations
    assert user.received_invitations.count > 0
    assert_instance_of FamilyInvitation, user.received_invitations.first
  end
end
