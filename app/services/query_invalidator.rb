class QueryInvalidator
  def self.broadcast(resource, family, data = nil)
    ActionCable.server.broadcast(
      "family_invalidation_stream_#{family.id}",
      {resource:, data:}
    )
  end
end
