class AddMetadataToChatThreads < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_threads, :metadata, :jsonb, default: {}, null: false
    add_index :chat_threads, :metadata, using: :gin
  end
end
