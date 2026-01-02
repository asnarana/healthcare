# chat controller
# handles llm-powered chat queries
# forwards requests to fastapi microservice which uses langchain + ollama
class ChatController < ApplicationController
  # query action - process chat query via fastapi llm service
  def query
    user_query = params[:query] || params[:message]
    
    if user_query.blank?
      render json: { error: "Query cannot be blank" }, status: :bad_request
      return
    end

    begin
      # forward to fastapi service
      # the fastapi service uses langchain tools to query oracle database
      # and ollama (local llm) to generate natural language responses
      fastapi_url = ENV.fetch('FASTAPI_URL', 'http://fastapi:8000')
      response = HTTParty.post(
        "#{fastapi_url}/chat",
        body: {
          query: user_query,
          context: {
            zip_code: params[:zip_code],
            date_range: params[:date_range]
          }
        }.to_json,
        headers: {
          'Content-Type' => 'application/json'
        },
        timeout: 60
      )

      if response.success?
        render json: JSON.parse(response.body)
      else
        render json: { error: "LLM service error: #{response.code}" }, status: :bad_gateway
      end

    rescue => e
      Rails.logger.error "Chat error: #{e.message}"
      render json: { error: "Error processing query: #{e.message}" }, status: :internal_server_error
    end
  end
end

