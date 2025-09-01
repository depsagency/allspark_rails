class AddMetadataIndexesToKnowledgeDocuments < ActiveRecord::Migration[8.0]
  def up
    # First, convert JSON columns to JSONB for better performance and indexing
    change_column :knowledge_documents, :metadata, :jsonb, default: {}, using: 'metadata::jsonb'
    change_column :knowledge_chunks, :metadata, :jsonb, default: {}, using: 'metadata::jsonb'
    
    # GIN indexes for JSONB metadata fields to improve query performance
    
    # Index for tags array queries
    add_index :knowledge_documents, "(metadata -> 'tags')", 
              using: :gin, 
              name: 'index_knowledge_documents_on_metadata_tags'
    
    # Index for category queries
    add_index :knowledge_documents, "(metadata ->> 'category')", 
              name: 'index_knowledge_documents_on_metadata_category'
    
    # Index for project queries
    add_index :knowledge_documents, "(metadata ->> 'project')", 
              name: 'index_knowledge_documents_on_metadata_project'
    
    # Index for visibility queries
    add_index :knowledge_documents, "(metadata ->> 'visibility')", 
              name: 'index_knowledge_documents_on_metadata_visibility'
    
    # Index for priority queries
    add_index :knowledge_documents, "(metadata ->> 'priority')", 
              name: 'index_knowledge_documents_on_metadata_priority'
    
    # General GIN index for all metadata queries
    add_index :knowledge_documents, :metadata, 
              using: :gin, 
              name: 'index_knowledge_documents_on_metadata_gin'
    
    # Same indexes for knowledge_chunks
    add_index :knowledge_chunks, "(metadata -> 'tags')", 
              using: :gin, 
              name: 'index_knowledge_chunks_on_metadata_tags'
    
    add_index :knowledge_chunks, :metadata, 
              using: :gin, 
              name: 'index_knowledge_chunks_on_metadata_gin'
  end
  
  def down
    # Remove indexes
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_tags'
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_category'
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_project'
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_visibility'
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_priority'
    remove_index :knowledge_documents, name: 'index_knowledge_documents_on_metadata_gin'
    
    remove_index :knowledge_chunks, name: 'index_knowledge_chunks_on_metadata_tags'
    remove_index :knowledge_chunks, name: 'index_knowledge_chunks_on_metadata_gin'
    
    # Convert back to JSON
    change_column :knowledge_documents, :metadata, :json, default: {}, using: 'metadata::json'
    change_column :knowledge_chunks, :metadata, :json, default: {}, using: 'metadata::json'
  end
end
