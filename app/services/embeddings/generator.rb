# frozen_string_literal: true

module Embeddings
  class Generator
    attr_reader :client, :model
    
    def initialize(model: 'text-embedding-3-small')
      @model = model
      @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    end
    
    # Generate embedding for text
    def generate(text)
      return nil if text.blank?
      
      response = client.embeddings(
        parameters: {
          model: model,
          input: text.truncate(8000) # Limit input size
        }
      )
      
      response.dig('data', 0, 'embedding')
    rescue => e
      Rails.logger.error "Embedding generation failed: #{e.message}"
      nil
    end
    
    # Generate embeddings for multiple texts
    def generate_batch(texts)
      return [] if texts.empty?
      
      # OpenAI supports batch embeddings
      response = client.embeddings(
        parameters: {
          model: model,
          input: texts.map { |t| t.truncate(8000) }
        }
      )
      
      response['data'].map { |d| d['embedding'] }
    rescue => e
      Rails.logger.error "Batch embedding generation failed: #{e.message}"
      []
    end
    
    # Calculate similarity between two embeddings
    def self.cosine_similarity(embedding1, embedding2)
      return 0.0 unless embedding1 && embedding2 && embedding1.size == embedding2.size
      
      dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(embedding1.sum { |a| a**2 })
      magnitude2 = Math.sqrt(embedding2.sum { |b| b**2 })
      
      return 0.0 if magnitude1 == 0 || magnitude2 == 0
      
      dot_product / (magnitude1 * magnitude2)
    end
  end
end