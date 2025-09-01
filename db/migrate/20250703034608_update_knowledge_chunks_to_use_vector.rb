class UpdateKnowledgeChunksToUseVector < ActiveRecord::Migration[8.0]
  def up
    # Remove the old embeddings column
    remove_column :knowledge_chunks, :embeddings if column_exists?(:knowledge_chunks, :embeddings)
    
    # Add the new vector column
    add_column :knowledge_chunks, :embedding, :vector, limit: 1536  # OpenAI embeddings dimension
    
    # Add an index for similarity searches
    add_index :knowledge_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
  
  def down
    remove_column :knowledge_chunks, :embedding
    add_column :knowledge_chunks, :embeddings, :text
  end
end
