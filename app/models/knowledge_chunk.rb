# frozen_string_literal: true

class KnowledgeChunk < ApplicationRecord
  belongs_to :knowledge_document
  
  # Neighbor for vector similarity search with pgvector
  has_neighbors :embedding
  
  # Validations
  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :knowledge_document_id }
  
  # Scopes
  scope :ordered, -> { order(:position) }
  
  # Generate embedding for chunk
  def generate_embedding!
    embedding_vector = Embeddings::Generator.new.generate(content)
    
    # Store as pgvector embedding
    self.embedding = embedding_vector
    save!
  end
  
  # Search for similar chunks using pgvector
  def self.search(query, limit: 10, assistant: nil)
    query_embedding = Embeddings::Generator.new.generate(query)
    return [] unless query_embedding
    
    # Build scope based on assistant
    scope = includes(:knowledge_document)
    if assistant
      scope = scope.joins(:knowledge_document)
                   .where(knowledge_documents: { assistant_id: [assistant.id, nil] })
    end
    
    # Use pgvector nearest neighbor search with cosine distance
    chunks = scope.where.not(embedding: nil)
                  .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
                  .limit(limit)
    
    # Add context and similarity scores to results
    chunks.map do |chunk|
      # Calculate cosine similarity from cosine distance
      # cosine_similarity = 1 - cosine_distance
      # For neighbor gem, we need to calculate this manually
      similarity = 1.0 - chunk.neighbor_distance if chunk.respond_to?(:neighbor_distance)
      similarity ||= calculate_cosine_similarity(query_embedding, chunk.embedding)
      
      context_chunks = chunk.context(before: 1, after: 1)
      { 
        chunk: chunk, 
        similarity: similarity,
        context: context_chunks
      }
    end
  end
  
  # Get context around this chunk
  def context(before: 1, after: 1)
    document_chunks = knowledge_document.knowledge_chunks.ordered
    
    start_pos = [position - before, 0].max
    end_pos = [position + after, document_chunks.maximum(:position) || 0].min
    
    document_chunks.where(position: start_pos..end_pos).ordered
  end
  
  private
  
  def self.calculate_cosine_similarity(vec1, vec2)
    return 0.0 unless vec1 && vec2 && vec1.size == vec2.size
    
    dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
    magnitude1 = Math.sqrt(vec1.map { |a| a * a }.sum)
    magnitude2 = Math.sqrt(vec2.map { |b| b * b }.sum)
    
    return 0.0 if magnitude1 == 0 || magnitude2 == 0
    
    dot_product / (magnitude1 * magnitude2)
  end
end