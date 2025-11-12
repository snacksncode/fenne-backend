class Todo < ApplicationRecord
  validates :content, presence: true
  validates :is_completed, inclusion: { in: [ true, false ] }

  after_create_commit { QueryInvalidator.broadcast([ "todos" ]) }
  after_update_commit { QueryInvalidator.broadcast([ "todos" ]) }
  after_destroy_commit { QueryInvalidator.broadcast([ "todos" ]) }
end
