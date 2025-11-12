class InvalidationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "invalidation_stream"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
