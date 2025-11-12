class User < ApplicationRecord
  has_many :todos, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy
end
