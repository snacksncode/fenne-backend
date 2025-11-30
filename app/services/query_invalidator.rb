class QueryInvalidator
  def self.broadcast(resource, data = nil)
    ActionCable.server.broadcast(
      "invalidation_stream",
      {resource:, data:}
    )
  end
end
