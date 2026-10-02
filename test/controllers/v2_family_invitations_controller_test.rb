require "test_helper"

class V2FamilyInvitationsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "invite creates a request and notifies both participant families" do
    sender = users(:john_smith)
    recipient = users(:bob_johnson)

    assert_difference("FamilyInvitation.count", 1) do
      post "/v2/invitations", params: { email: recipient.email },
        headers: auth_headers_for(sender), as: :json
    end

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    invitation = sender.sent_invitations.find_by!(to_user: recipient)
    assert_equal sender.family, invitation.family
    assert_resources(sender.family, [ "invitations" ])
    assert_resources(recipient.family, [ "invitations" ])
  end

  test "duplicate invitation changes nothing and sends no broadcasts" do
    invitation = family_invitations(:charlie_invites_diana)

    assert_no_difference("FamilyInvitation.count") do
      post "/v2/invitations", params: { email: invitation.to_user.email },
        headers: auth_headers_for(invitation.from_user), as: :json
    end

    assert_response :bad_request
    assert_equal [ "User already invited" ], response.parsed_body.dig("errors", "base")
    assert_resources(invitation.from_user.family, [])
    assert_resources(invitation.to_user.family, [])
  end

  test "same family invitation changes nothing and sends no broadcasts" do
    sender = users(:john_smith)
    recipient = users(:jane_smith)

    assert_no_difference("FamilyInvitation.count") do
      post "/v2/invitations", params: { email: recipient.email },
        headers: auth_headers_for(sender), as: :json
    end

    assert_response :bad_request
    assert_equal [ "User already in your family" ], response.parsed_body.dig("errors", "base")
    assert_resources(sender.family, [])
  end

  test "cancel notifies both participants current families" do
    invitation = family_invitations(:charlie_invites_diana)
    sender = invitation.from_user
    recipient = invitation.to_user
    sender.update!(family: families(:smith_family))

    delete "/v2/invitations/#{invitation.id}", headers: auth_headers_for(sender)

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    assert_not FamilyInvitation.exists?(invitation.id)
    assert_resources(sender.family, [ "invitations" ])
    assert_resources(recipient.family, [ "invitations" ])
    assert_resources(invitation.family, [])
  end

  test "decline notifies both participants current families" do
    invitation = family_invitations(:charlie_invites_diana)

    post "/v2/invitations/#{invitation.id}/decline", headers: auth_headers_for(invitation.to_user)

    assert_response :success
    assert_not FamilyInvitation.exists?(invitation.id)
    assert_resources(invitation.from_user.family, [ "invitations" ])
    assert_resources(invitation.to_user.family, [ "invitations" ])
  end

  test "invitation removal notifies a shared participant family only once" do
    invitation = family_invitations(:charlie_invites_diana)
    invitation.to_user.update!(family: invitation.from_user.family)

    delete "/v2/invitations/#{invitation.id}", headers: auth_headers_for(invitation.from_user)

    assert_response :success
    assert_resources(invitation.from_user.family, [ "invitations" ])
  end

  test "only the sender can cancel and only the recipient can accept or decline" do
    invitation = family_invitations(:charlie_invites_diana)

    delete "/v2/invitations/#{invitation.id}", headers: auth_headers_for(invitation.to_user)
    assert_response :not_found
    [ :accept, :decline ].each do |action|
      post "/v2/invitations/#{invitation.id}/#{action}", headers: auth_headers_for(invitation.from_user)
      assert_response :not_found
      assert_equal "error", response.parsed_body["status"]
    end

    assert FamilyInvitation.exists?(invitation.id)
    assert_resources(invitation.from_user.family, [])
    assert_resources(invitation.to_user.family, [])
  end

  test "accept joins the invited family even if the sender moved and notifies affected families" do
    invitation = family_invitations(:charlie_invites_diana)
    recipient = invitation.to_user
    previous_family = recipient.family
    destination_family = invitation.family
    sender_family = families(:smith_family)
    invitation.from_user.update!(family: sender_family)

    post "/v2/invitations/#{invitation.id}/accept", headers: auth_headers_for(recipient)

    assert_response :success
    assert_equal "success", response.parsed_body["status"]
    assert_equal destination_family.id.to_s, response.parsed_body.dig("data", "id")
    assert_equal destination_family, recipient.reload.family
    assert_not FamilyInvitation.exists?(invitation.id)
    assert_resources(previous_family, [ "invitations", "family_members" ])
    assert_resources(destination_family, [ "invitations", "family_members" ])
    assert_resources(sender_family, [ "invitations" ])
  end

  test "failed invitation deletion rolls back acceptance and sends no broadcasts" do
    invitation = family_invitations(:charlie_invites_diana)
    recipient = invitation.to_user
    previous_family = recipient.family
    stop_destroy = -> { throw :abort }

    with_callback(FamilyInvitation, :destroy, stop_destroy) do
      assert_raises(ActiveRecord::RecordNotDestroyed) do
        post "/v2/invitations/#{invitation.id}/accept", headers: auth_headers_for(recipient)
      end
    end

    assert_equal previous_family, recipient.reload.family
    assert FamilyInvitation.exists?(invitation.id)
    assert_resources(previous_family, [])
    assert_resources(invitation.family, [])
  end

  test "leave creates a family and updates membership" do
    user = users(:john_smith)
    previous_family = user.family

    assert_difference("Family.count", 1) do
      post "/v2/leave_family", headers: auth_headers_for(user)
    end

    assert_response :success
    assert_not_equal previous_family, user.reload.family
    assert_equal user.family_id.to_s, response.parsed_body.dig("data", "id")
    assert_resources(previous_family, [ "invitations", "family_members" ])
    assert_resources(user.family, [ "family_members" ])
  end

  test "failed membership update rolls back the new family and sends no broadcasts" do
    user = users(:john_smith)
    previous_family = user.family
    stop_update = -> { throw :abort }

    with_callback(User, :update, stop_update) do
      assert_no_difference("Family.count") do
        post "/v2/leave_family", headers: auth_headers_for(user)
        assert_response :unprocessable_entity
      end
    end

    assert_equal previous_family, user.reload.family
    assert_resources(previous_family, [])
  end

  test "a sole member cannot leave their family" do
    user = users(:charlie_wilson)
    previous_family = user.family

    assert_no_difference("Family.count") do
      post "/v2/leave_family", headers: auth_headers_for(user)
    end

    assert_response :bad_request
    assert_equal [ "cannot leave family" ], response.parsed_body.dig("errors", "base")
    assert_equal previous_family, user.reload.family
    assert_resources(previous_family, [])
  end

  private

  def assert_resources(family, expected)
    messages = broadcasts("family_invalidation_stream_#{family.id}").map { |message| JSON.parse(message) }
    assert_equal expected.sort, messages.map { |message| message.fetch("resource") }.sort
  end

  def with_callback(model, operation, callback)
    model.set_callback(operation, :before, callback)
    yield
  ensure
    model.skip_callback(operation, :before, callback)
  end
end
