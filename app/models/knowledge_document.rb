# frozen_string_literal: true

class KnowledgeDocument < ApplicationRecord
  include Taggable
  
  belongs_to :assistant, optional: true
  belongs_to :user
  has_many :knowledge_chunks, dependent: :destroy
  
  # ActiveStorage
  has_one_attached :file
  
  # Neighbor for vector similarity search (if pgvector is available)
  has_neighbors :embedding_vector if respond_to?(:has_neighbors)
  
  # Validations
  validates :title, presence: true
  validate :content_or_file_present
  
  private
  
  def content_or_file_present
    # During creation, check if a file is being attached
    if content.blank? && !file.attached? && !file.attachment_changes.present?
      errors.add(:base, "Either content or file must be provided")
    end
  end
  
  public
  
  # Serialize embedding data
  serialize :embedding_data, coder: JSON
  
  # Virtual attribute for embedding
  def embedding
    embedding_data
  end
  
  def embedding=(value)
    self.embedding_data = value
  end
  
  # Scopes
  scope :for_assistant, ->(assistant) { where(assistant: assistant) }
  scope :global, -> { where(assistant_id: nil) }
  
  # Get processing status
  def processing_status
    if knowledge_chunks.any?
      "completed"
    elsif file.attached? && content.blank?
      "pending"
    elsif content.present? && knowledge_chunks.empty?
      "processing"
    else
      "ready"
    end
  end
  
  # Check if document is being processed
  def processing?
    processing_status == "processing"
  end
  
  # Check if document has been processed
  def processed?
    knowledge_chunks.any?
  end
  
  # Process document into chunks and generate embeddings
  def process!
    ActiveRecord::Base.transaction do
      # Clear existing chunks
      knowledge_chunks.destroy_all
      
      # Split content into chunks
      chunks = chunk_content(content)
      
      # Create chunks with embeddings
      chunks.each_with_index do |chunk_text, index|
        chunk = knowledge_chunks.create!(
          content: chunk_text,
          position: index
        )
        
        # Generate embedding for chunk
        chunk.generate_embedding!
      end
      
      # Generate embedding for the whole document (title + summary)
      generate_embedding!
    end
  end
  
  # Generate embedding for document
  def generate_embedding!
    embedding_text = "#{title}\n\n#{content.truncate(500)}"
    embedding = Embeddings::Generator.new.generate(embedding_text)
    
    # Store in both formats for compatibility
    self.embedding_data = embedding
    self.embedding_vector = embedding if has_attribute?(:embedding_vector)
    save!
  end
  
  # Search for similar documents
  def self.search(query, limit: 5, assistant: nil)
    query_embedding = Embeddings::Generator.new.generate(query)
    return [] unless query_embedding
    
    scope = assistant ? for_assistant(assistant) : all
    
    # Use pgvector if available
    if column_names.include?('embedding_vector') && defined?(Neighbor)
      scope.nearest_neighbors(:embedding_vector, query_embedding, distance: "euclidean")
           .limit(limit)
    else
      # Fallback to in-memory search
      documents = scope.where.not(embedding_data: nil)
      
      # Calculate similarities
      similarities = documents.map do |doc|
        next unless doc.embedding_data
        
        similarity = Embeddings::Generator.cosine_similarity(query_embedding, doc.embedding_data)
        { document: doc, similarity: similarity }
      end.compact
      
      # Sort by similarity and return top results
      similarities.sort_by { |s| -s[:similarity] }
                 .first(limit)
                 .map { |s| s[:document] }
    end
  end
  
  # Enhanced search with metadata filters
  def self.advanced_search(query, filters = {}, limit: 10, assistant: nil)
    # Start with basic scope
    scope = assistant ? for_assistant(assistant) : all
    
    # Apply metadata filters first
    scope = scope.search_with_metadata(query, filters)
    
    # If query is provided, do semantic search within filtered results
    if query.present?
      query_embedding = Embeddings::Generator.new.generate(query)
      
      if query_embedding && column_names.include?('embedding_vector') && defined?(Neighbor)
        # Use pgvector on filtered scope
        scope = scope.nearest_neighbors(:embedding_vector, query_embedding, distance: "euclidean")
                     .limit(limit)
      elsif query_embedding
        # Fallback to in-memory search on filtered scope
        documents = scope.where.not(embedding_data: nil)
        
        similarities = documents.map do |doc|
          next unless doc.embedding_data
          
          similarity = Embeddings::Generator.cosine_similarity(query_embedding, doc.embedding_data)
          { document: doc, similarity: similarity }
        end.compact
        
        scope = similarities.sort_by { |s| -s[:similarity] }
                           .first(limit)
                           .map { |s| s[:document] }
      else
        # No embedding, just return filtered results
        scope = scope.limit(limit)
      end
    else
      # No query, just return filtered results
      scope = scope.order(created_at: :desc).limit(limit)
    end
    
    scope
  end
  
  # Get suggested tags based on content
  def suggest_tags(max_tags: 5)
    # Simple implementation - can be enhanced with NLP
    words = (title + ' ' + content.to_s).downcase.split(/\W+/)
    
    # Remove common words
    stop_words = %w[the a an and or but in on at to for of with as by from up about into through during before after above below between under since without within along following across behind beyond plus except but even]
    words = words - stop_words
    
    # Count word frequency
    word_counts = words.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 if word.length > 3 }
    
    # Get top words as suggested tags
    word_counts.sort_by { |_, count| -count }
               .first(max_tags)
               .map { |word, _| word }
  end
  
  private
  
  def chunk_content(text, chunk_size: 1000, overlap: 100)
    chunks = []
    words = text.split(/\s+/)
    
    i = 0
    while i < words.length
      chunk_words = words[i...[i + chunk_size, words.length].min]
      chunks << chunk_words.join(' ')
      
      # Move forward with overlap
      i += (chunk_size - overlap)
    end
    
    chunks
  end
end