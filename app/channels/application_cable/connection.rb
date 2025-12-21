module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :user

    def connect
      self.user = find_user_by_token!
    end

    private

    def find_user_by_token!
      SessionToken.find_by!(token: request.params[:token]).user
    rescue ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
