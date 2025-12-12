class User < ApplicationRecord
  before_validation do
    self.family = Family.create! unless family
  end

  has_secure_password
  has_many :session_tokens, dependent: :destroy
  belongs_to :family
  has_many :sent_invitations, class_name: "FamilyInvitation", foreign_key: "from_user_id"
  has_many :received_invitations, class_name: "FamilyInvitation", foreign_key: "to_user_id"
  validates :email, uniqueness: true
end
