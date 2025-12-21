class InvalidationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "family_invalidation_stream_#{user.family.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
