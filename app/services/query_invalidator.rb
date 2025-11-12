class QueryInvalidator
  def self.broadcast(query_key)
    ActionCable.server.broadcast(
      "invalidation_stream",
      {
        action: "invalidate",
        query_key: query_key
      }
    )
  end
end
