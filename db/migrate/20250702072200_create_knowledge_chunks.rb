class CreateKnowledgeChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_chunks, id: :uuid do |t|
      t.references :knowledge_document, type: :uuid, foreign_key: true
      t.text :content, null: false
      t.integer :position, null: false
      # t.vector :embedding, limit: 1536
      t.text :embedding_data
      t.json :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :knowledge_chunks, [:knowledge_document_id, :position], unique: true
    # add_index :knowledge_chunks, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end