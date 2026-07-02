class FamilyInvitationSerializer
  def self.render(family_invitation)
    {
      id: family_invitation.id.to_s,
      from_user: UserSerializer.render(family_invitation.from_user),
      to_user: UserSerializer.render(family_invitation.to_user)
    }
  end

  def self.render_many(family_invitations)
    family_invitations.map { |i| render(i) }
  end
end
