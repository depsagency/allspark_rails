class CreateChatThreadParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :allspark_chat_thread_participants do |t|
      t.references :chat_thread, null: false, foreign_key: { to_table: :allspark_chat_threads }
      t.uuid :user_id, null: false
      t.datetime :last_read_at
      t.timestamps
    end
    
    add_foreign_key :allspark_chat_thread_participants, :users

    add_index :allspark_chat_thread_participants, [:chat_thread_id, :user_id], unique: true
  end
end
