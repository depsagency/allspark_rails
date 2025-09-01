class AddVectorColumnsToKnowledgeDocuments < ActiveRecord::Migration[8.0]
  def up
    # Check if vector extension is enabled
    result = execute("SELECT * FROM pg_extension WHERE extname = 'vector';")
    
    if result.any?
      # Add vector columns for embeddings (using 1536 dimensions for OpenAI embeddings)
      add_column :knowledge_documents, :embedding_vector, :vector, limit: 1536
      add_column :knowledge_chunks, :embedding_vector, :vector, limit: 1536
      
      # Add indexes for similarity search
      add_index :knowledge_documents, :embedding_vector, using: :hnsw, opclass: :vector_l2_ops
      add_index :knowledge_chunks, :embedding_vector, using: :hnsw, opclass: :vector_l2_ops
      
      Rails.logger.info "pgvector columns and indexes created successfully"
    else
      Rails.logger.warn "pgvector extension not enabled, skipping vector columns"
      Rails.logger.info "RAG system will continue to work with text-based embeddings"
    end
  end
  
  def down
    # Check if columns exist before trying to remove them
    if column_exists?(:knowledge_documents, :embedding_vector)
      remove_index :knowledge_documents, :embedding_vector
      remove_column :knowledge_documents, :embedding_vector
    end
    
    if column_exists?(:knowledge_chunks, :embedding_vector)
      remove_index :knowledge_chunks, :embedding_vector
      remove_column :knowledge_chunks, :embedding_vector
    end
  end
end