class RenameRefreshTokensToSessionTokens < ActiveRecord::Migration[8.0]
  def change
    rename_table :refresh_tokens, :session_tokens
  end
end
