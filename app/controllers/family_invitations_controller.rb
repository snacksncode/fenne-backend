class FamilyInvitationsController < ApplicationController
  def show
    render json: {
      received: FamilyInvitationSerializer.render_many(@current_user.received_invitations),
      sent: FamilyInvitationSerializer.render_many(@current_user.sent_invitations)
    }
  end

  def invite
    email, is_valid = get_email
    return bad_request!("Email format invalid") unless is_valid

    user = User.find_by!(email:)
    return bad_request!("User already in your family") unless user.family.id != @current_user.family.id

    user_already_invited = @current_user.sent_invitations.find_by(to_user: user).present?
    return bad_request!("User already invited") if user_already_invited

    @current_user.sent_invitations.create!(to_user: user, family: @current_user.family)
    invalidate_invitations!(@current_user.family)
    invalidate_invitations!(user.family)
    render json: {success: true}
  end

  def destroy
    invite = get_sent_invite
    invite.destroy!
    invalidate_invitations!(@current_user.family)
    invalidate_invitations!(invite.from_user.family)
    render json: {success: true}
  end

  def leave
    return bad_request! if @current_user.family.users.size == 1
    @current_user.update(family: Family.create!)
    invalidate_invitations!(@current_user.family)
    invalidate_family_members!(@current_user.family)
    render json: {success: true}
  end

  def accept
    previous_family = @current_user.family
    invite = get_received_invite
    @current_user.update(family: invite.family)
    invite.destroy!

    [previous_family, invite.family].each do |family|
      invalidate_invitations!(family)
      invalidate_family_members!(family)
    end

    render json: {success: true}
  end

  def decline
    invite = get_received_invite
    invite.destroy!
    invalidate_invitations!(@current_user.family)
    render json: {success: true}
  end

  private

  def invalidate_invitations!(family)
    QueryInvalidator.broadcast(:invitations, family)
  end

  def invalidate_family_members!(family)
    QueryInvalidator.broadcast(:family_members, family)
  end

  def get_received_invite
    @current_user.received_invitations.find(params[:invitation_id])
  end

  def get_sent_invite
    @current_user.sent_invitations.find(params[:invitation_id])
  end

  def get_email
    email = params.expect(:email)
    is_valid = email.match?(URI::MailTo::EMAIL_REGEXP)
    [email.downcase, is_valid]
  end
end
