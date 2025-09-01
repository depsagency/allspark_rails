class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :allspark_chat_messages do |t|
      t.references :chat_thread, null: false, foreign_key: { to_table: :allspark_chat_threads }
      t.uuid :user_id, null: false
      t.text :content, null: false
      t.boolean :edited, default: false
      t.datetime :edited_at
      t.timestamps
    end
    
    add_foreign_key :allspark_chat_messages, :users

    add_index :allspark_chat_messages, :created_at
  end
end
