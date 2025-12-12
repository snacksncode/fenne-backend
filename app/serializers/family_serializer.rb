class FamilySerializer
  def self.render(family)
    {
      id: family.id.to_s,
      members: family.users.map { |u| UserSerializer.render(u) }
    }
  end
end
