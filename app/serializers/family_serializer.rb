class FamilySerializer
  def self.render(family)
    {
      id: family.id.to_s,
      unit_preference: family.unit_preference,
      members: family.users.map { |u| UserSerializer.render(u) }
    }
  end
end
