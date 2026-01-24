require "test_helper"

class FamilyInvitationTest < ActiveSupport::TestCase
  test "belongs to family" do
    invitation = family_invitations(:charlie_invites_diana)

    assert_instance_of Family, invitation.family
  end

  test "belongs to from_user" do
    invitation = family_invitations(:charlie_invites_diana)

    assert_instance_of User, invitation.from_user
    assert_equal users(:charlie_wilson), invitation.from_user
  end

  test "belongs to to_user" do
    invitation = family_invitations(:charlie_invites_diana)

    assert_instance_of User, invitation.to_user
    assert_equal users(:diana_lee), invitation.to_user
  end

  test "can create invitation" do
    invitation = FamilyInvitation.new(
      family: families(:smith_family),
      from_user: users(:john_smith),
      to_user: users(:diana_lee)
    )

    assert invitation.valid?
  end
end
