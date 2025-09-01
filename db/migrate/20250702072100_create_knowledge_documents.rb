class CreateKnowledgeDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_documents, id: :uuid do |t|
      t.references :assistant, type: :uuid, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.string :source_type # file, url, manual
      t.string :source_url
      t.json :metadata, default: {}
      # t.vector :embedding, limit: 1536 # Requires pgvector extension
      t.text :embedding_data # Store as JSON text for now
      
      t.timestamps
    end
    
    # add_index :knowledge_documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
    add_index :knowledge_documents, :title
    add_index :knowledge_documents, :source_type
  end
end