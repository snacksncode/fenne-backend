module V2
  class FamilyInvitationsController < ApplicationController
    class InviteContract < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
      end

      rule(:email) do
        key.failure("format invalid") unless URI::MailTo::EMAIL_REGEXP.match?(value)
      end
    end

    def show
      render_success({
        received: FamilyInvitationSerializer.render_many(@current_user.received_invitations.includes(:from_user, :to_user)),
        sent: FamilyInvitationSerializer.render_many(@current_user.sent_invitations.includes(:from_user, :to_user))
      })
    end

    def invite
      email = get_email

      user = User.find_by!(email: email)
      return render_error({ base: [ "User already in your family" ] }, status: :bad_request) unless user.family.id != @current_user.family.id
      return render_error({ base: [ "User already invited" ] }, status: :bad_request) if @current_user.sent_invitations.find_by(to_user: user).present?

      @current_user.sent_invitations.create!(to_user: user, family: @current_user.family)
      invalidate_invitations!(@current_user.family)
      invalidate_invitations!(user.family)
      render_success
    end

    def destroy
      invite = get_sent_invite
      invite.destroy!
      invalidate_invitations!(@current_user.family)
      invalidate_invitations!(invite.from_user.family)
      render_success
    end

    def leave
      return render_error({ base: [ "cannot leave family" ] }, status: :bad_request) if @current_user.family.users.size == 1

      previous_family = @current_user.family
      @current_user.update!(family: Family.create!)
      invalidate_invitations!(previous_family)
      invalidate_family_members!(previous_family)
      invalidate_family_members!(@current_user.family)
      render_success(FamilySerializer.render(@current_user.family))
    end

    def accept
      previous_family = @current_user.family
      invite = get_received_invite
      @current_user.update!(family: invite.family)
      invite.destroy!

      [ previous_family, invite.family ].each do |family|
        invalidate_invitations!(family)
        invalidate_family_members!(family)
      end

      render_success(FamilySerializer.render(@current_user.family))
    end

    def decline
      invite = get_received_invite
      invite.destroy!
      invalidate_invitations!(@current_user.family)
      render_success
    end

    private

    def get_received_invite
      @current_user.received_invitations.find(params[:invitation_id])
    end

    def get_sent_invite
      @current_user.sent_invitations.find(params[:invitation_id])
    end

    def get_email
      validate_params!(InviteContract)[:email].downcase
    end
  end
end
