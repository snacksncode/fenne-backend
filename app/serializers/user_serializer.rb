class UserSerializer
  def self.render(user)
    {
      id: user.id.to_s,
      email: user.email,
      name: user.name
    }
  end
end
