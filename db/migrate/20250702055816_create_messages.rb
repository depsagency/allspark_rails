class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :assistant_messages, id: :uuid do |t|
      t.references :assistant, type: :uuid, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.json :tool_calls, default: []
      t.string :tool_call_id
      t.string :run_id
      t.json :metadata, default: {}
      
      t.timestamps
    end

    add_index :assistant_messages, :role
    add_index :assistant_messages, :run_id
    add_index :assistant_messages, :created_at
  end
end
