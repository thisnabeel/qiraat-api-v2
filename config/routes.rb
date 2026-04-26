Rails.application.routes.draw do
  namespace :api do
    resource :global_config, only: [:show]

    namespace :admin do
      post "verse_marker_session", to: "verse_marker_sessions#create"
      get "verse_marker_session", to: "verse_marker_sessions#show"
    end

    resources :reciters, only: [:index]
    get "reciters/:reciter_slug/recitations", to: "recitations#index", as: :reciter_recitations
    post "recitations/:id/generate_segments", to: "recitations#generate_segments"
    get "recitation_verse_segments/lookup", to: "recitation_verse_segments#lookup"
    get "recitations/:recitation_id/verse_segments", to: "recitation_verse_segments#index"
    put "recitations/:recitation_id/verse_segments", to: "recitation_verse_segments#update"

    resources :narrators, only: [:index]
    get "variations/counts_by_surah", to: "variations#counts_by_surah"
    resources :variations, only: [:index, :show, :create, :destroy] do
      collection do
        delete "by_keys", to: "variations#destroy_by_keys"
      end
    end
    resources :words, only: [:index, :show]
    # Declared before nested `pages` so it never competes with `…/pages/:id`.
    get "mushafs/:id/surah_header_markers", to: "mushafs#surah_header_markers", as: :mushaf_surah_header_markers
    get "mushafs/:id/preceding_surah_carry", to: "mushafs#preceding_surah_carry"
    resources :mushafs, only: [:index, :show] do
      member do
        get :segments
      end
      resources :pages, only: [:show] do
        member do
          post :insert_surah_header
          patch :bulk_update_ayahs
        end
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
