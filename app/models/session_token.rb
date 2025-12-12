class SessionToken < ApplicationRecord
  belongs_to :user
  before_create :generate_token
  before_create :enforce_token_limit

  def expired?
    expires_at < Time.current
  end

  def needs_refresh?
    expires_at < 60.days.from_now
  end

  def refresh!
    update!(expires_at: 90.days.from_now)
  end

  private

  def generate_token
    self.token = SecureRandom.hex(32)
    self.expires_at = 90.days.from_now
  end

  def enforce_token_limit
    user.session_tokens.order(created_at: :desc).offset(4).destroy_all
  end
end
