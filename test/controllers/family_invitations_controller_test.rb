require "test_helper"

class FamilyInvitationsControllerTest < ActionDispatch::IntegrationTest
  # GET /invitations
  test "show returns sent and received invitations" do
    user = users(:charlie_wilson)

    get "/invitations", headers: auth_headers_for(user)

    assert_response :success
    json = response.parsed_body
    assert_not_nil json["sent"]
    assert_not_nil json["received"]
    assert json["sent"].is_a?(Array)
    assert json["received"].is_a?(Array)
  end

  test "show requires authentication" do
    get "/invitations"

    assert_response :unauthorized
  end

  # POST /invitations
  test "invite creates invitation to another user" do
    sender = users(:john_smith)
    recipient = users(:diana_lee)

    assert_difference("FamilyInvitation.count", 1) do
      post "/invitations",
        params: {email: recipient.email},
        headers: auth_headers_for(sender),
        as: :json
    end

    assert_response :success
    json = response.parsed_body
    assert_equal true, json["success"]

    invitation = FamilyInvitation.last
    assert_equal sender, invitation.from_user
    assert_equal recipient, invitation.to_user
    assert_equal sender.family, invitation.family
  end

  test "invite downcases email" do
    sender = users(:john_smith)
    recipient = users(:diana_lee)

    post "/invitations",
      params: {email: recipient.email.upcase},
      headers: auth_headers_for(sender),
      as: :json

    assert_response :success
  end

  test "invite returns error for invalid email format" do
    sender = users(:john_smith)

    post "/invitations",
      params: {email: "invalid-email"},
      headers: auth_headers_for(sender),
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "Email format invalid"
  end

  test "invite returns error for non-existent user" do
    sender = users(:john_smith)

    post "/invitations",
      params: {email: "nonexistent@example.com"},
      headers: auth_headers_for(sender),
      as: :json

    assert_response :not_found
  end

  test "invite returns error if user already in same family" do
    sender = users(:john_smith)
    same_family_user = users(:jane_smith)

    post "/invitations",
      params: {email: same_family_user.email},
      headers: auth_headers_for(sender),
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "User already in your family"
  end

  test "invite returns error if user already invited" do
    sender = users(:charlie_wilson)
    recipient = users(:diana_lee)

    # First invitation exists in fixtures
    post "/invitations",
      params: {email: recipient.email},
      headers: auth_headers_for(sender),
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "User already invited"
  end

  test "invite requires authentication" do
    post "/invitations",
      params: {email: "test@example.com"},
      as: :json

    assert_response :unauthorized
  end

  # POST /invitations/:invitation_id/accept
  test "accept joins user to invitation family" do
    recipient = users(:diana_lee)
    invitation = family_invitations(:charlie_invites_diana)
    original_family = recipient.family

    post "/invitations/#{invitation.id}/accept", headers: auth_headers_for(recipient)

    assert_response :success
    recipient.reload
    assert_equal invitation.family, recipient.family
    assert_not_equal original_family, recipient.family
    assert_not FamilyInvitation.exists?(invitation.id)
  end

  test "accept requires authentication" do
    invitation = family_invitations(:charlie_invites_diana)

    post "/invitations/#{invitation.id}/accept"

    assert_response :unauthorized
  end

  test "accept returns 404 if invitation not received by user" do
    user = users(:john_smith)
    other_invitation = family_invitations(:charlie_invites_diana)

    post "/invitations/#{other_invitation.id}/accept", headers: auth_headers_for(user)

    assert_response :not_found
  end

  # POST /invitations/:invitation_id/decline
  test "decline deletes invitation" do
    recipient = users(:diana_lee)
    invitation = family_invitations(:charlie_invites_diana)

    assert_difference("FamilyInvitation.count", -1) do
      post "/invitations/#{invitation.id}/decline", headers: auth_headers_for(recipient)
    end

    assert_response :success
    assert_not FamilyInvitation.exists?(invitation.id)
  end

  test "decline requires authentication" do
    invitation = family_invitations(:charlie_invites_diana)

    post "/invitations/#{invitation.id}/decline"

    assert_response :unauthorized
  end

  # DELETE /invitations/:invitation_id
  test "destroy cancels sent invitation" do
    sender = users(:charlie_wilson)
    invitation = family_invitations(:charlie_invites_diana)

    assert_difference("FamilyInvitation.count", -1) do
      delete "/invitations/#{invitation.id}", headers: auth_headers_for(sender)
    end

    assert_response :success
    assert_not FamilyInvitation.exists?(invitation.id)
  end

  test "destroy returns 404 if invitation not sent by user" do
    user = users(:john_smith)
    other_invitation = family_invitations(:charlie_invites_diana)

    delete "/invitations/#{other_invitation.id}", headers: auth_headers_for(user)

    assert_response :not_found
  end

  test "destroy requires authentication" do
    invitation = family_invitations(:charlie_invites_diana)

    delete "/invitations/#{invitation.id}"

    assert_response :unauthorized
  end

  # POST /leave_family
  test "leave_family creates new family for user" do
    user = users(:jane_smith)
    original_family = user.family
    original_family_user_count = original_family.users.count

    post "/leave_family", headers: auth_headers_for(user)

    assert_response :success
    user.reload
    assert_not_equal original_family, user.family
    assert_equal 1, user.family.users.count
    assert_equal original_family_user_count - 1, original_family.users.count
  end

  test "leave_family returns error if user is only member" do
    user = users(:diana_lee)

    post "/leave_family", headers: auth_headers_for(user)

    assert_response :bad_request
  end

  test "leave_family requires authentication" do
    post "/leave_family"

    assert_response :unauthorized
  end
end
