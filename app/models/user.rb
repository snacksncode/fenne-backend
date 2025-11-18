class User < ApplicationRecord
  before_validation do
    self.family = Family.create! unless family
  end

  has_secure_password
  has_many :todos, dependent: :destroy
  has_many :session_tokens, dependent: :destroy
  belongs_to :family
  validates :email, uniqueness: true
end
