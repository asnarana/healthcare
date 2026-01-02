Rails.application.routes.draw do
  # Dashboard route - shows health data for a specific zip code or coordinates
  get '/dashboard/:zip', to: 'dashboard#show', as: 'dashboard'
  get '/dashboard/search', to: 'dashboard#show', as: 'dashboard_search'
  
  # Chat endpoint - LLM-powered query interface
  post '/chat', to: 'chat#query', as: 'chat'
  
  # Prometheus metrics endpoint
  get '/metrics', to: 'metrics#index', as: 'metrics'
  
  # Root route
  root 'dashboard#index'
end
