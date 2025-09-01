class CreateChatThreads < ActiveRecord::Migration[8.0]
  def change
    create_table :allspark_chat_threads do |t|
      t.string :name, null: false
      t.references :context, polymorphic: true, null: true
      t.uuid :created_by_id, null: false
      t.timestamps
    end
    
    add_foreign_key :allspark_chat_threads, :users, column: :created_by_id

    add_index :allspark_chat_threads, [:context_type, :context_id]
  end
end
