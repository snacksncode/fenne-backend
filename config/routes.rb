Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :v2 do
    mount ActionCable.server => "/cable"

    post "/signup", to: "auth#signup"
    post "/login", to: "auth#login"
    post "/logout", to: "auth#logout"
    post "/change_password", to: "auth#change_password"
    post "/change_details", to: "auth#change_details"
    post "/convert_guest", to: "auth#convert_guest"
    post "/guest", to: "auth#guest"
    get "/me", to: "auth#me"
    delete "/delete_account", to: "auth#destroy"
    patch "/family/preferences", to: "family#preferences"

    resources :products do
      member do
        get :usages
      end
      collection do
        get :name_collision
      end
    end
    resources :suggestions, only: [:index]
    resources :pantry_entries, only: [:index, :create, :update, :destroy]
    resources :consumption_logs, only: [:index, :create, :destroy]

    get "/grocery_items/preview", to: "grocery_items#preview"
    post "/grocery_items/checkout", to: "grocery_items#checkout"
    post "/grocery_items/generate", to: "grocery_items#generate"
    post "/grocery_items/from_recipe", to: "grocery_items#from_recipe"
    resources :grocery_items

    resources :recipes

    get "/schedule", to: "schedule#index"
    post "/schedule", to: "schedule#create"
    put "/schedule/:date", to: "schedule#upsert"

    get "/invitations", to: "family_invitations#show"
    post "/invitations", to: "family_invitations#invite"
    post "/invitations/:invitation_id/accept", to: "family_invitations#accept"
    post "/invitations/:invitation_id/decline", to: "family_invitations#decline"
    delete "/invitations/:invitation_id", to: "family_invitations#destroy"
    post "/leave_family", to: "family_invitations#leave"
  end
end
