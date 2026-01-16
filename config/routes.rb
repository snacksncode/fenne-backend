Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # auth
  post "/signup", to: "auth#signup"
  post "/login", to: "auth#login"
  post "/logout", to: "auth#logout"
  post "/change_password", to: "auth#change_password"
  get "/me", to: "auth#me"

  # grocery items
  resources :grocery_items
  post "/grocery_items/checkout", to: "grocery_items#checkout"
  post "/grocery_items/generate", to: "grocery_items#generate"

  # recipes
  resources :recipes

  # schedule
  get "/schedule", to: "schedule#index"
  post "/schedule", to: "schedule#create"
  put "/schedule/:date", to: "schedule#upsert"

  # invitations
  get "/invitations", to: "family_invitations#show"
  post "/invitations", to: "family_invitations#invite"
  post "/invitations/:invitation_id/accept", to: "family_invitations#accept"
  post "/invitations/:invitation_id/decline", to: "family_invitations#decline"
  delete "/invitations/:invitation_id", to: "family_invitations#destroy"
  post "/leave_family", to: "family_invitations#leave"

  # autocomplete search
  get "/search", to: "search#index"
  delete "/search/:id", to: "search#destroy"

  # websockets
  mount ActionCable.server => "/cable"
end
