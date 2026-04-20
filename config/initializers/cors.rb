# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Vercel production + preview URLs (*.vercel.app), and local dev
    origins(
      /\Ahttps:\/\/.+\.vercel\.app\z/,
      "https://qiraat-react-native.vercel.app",
      # Svelte/Vite admin (verse-marker) and any local dev port hitting Railway directly
      /\Ahttp:\/\/localhost(:\d+)?\z/,
      /\Ahttp:\/\/127\.0\.0\.1(:\d+)?\z/,
      "http://localhost:19006",
      "http://localhost:3000",
      "http://localhost:5173",
      "http://127.0.0.1:5173",
      "http://localhost:8081"
    )

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
