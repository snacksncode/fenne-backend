class FamilyInvitationSerializer
  def self.render(invitation)
    {
      id: invitation.id.to_s,
      from_user: UserSerializer.render(User.find(invitation.from_user_id)),
      to_user: UserSerializer.render(User.find(invitation.to_user_id))
    }
  end

  def self.render_many(invitations)
    invitations.map { |i| render(i) }
  end
end
