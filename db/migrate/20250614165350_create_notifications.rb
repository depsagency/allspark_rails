class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :sender, null: true, foreign_key: { to_table: :users }, type: :uuid

      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, null: false, default: 'info'
      t.string :action_url
      t.json :metadata, default: {}

      t.timestamp :read_at
      t.timestamp :delivered_at
      t.timestamp :expires_at

      t.integer :priority, default: 0
      t.boolean :persistent, default: false

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read_at ]
    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, [ :notification_type ]
    add_index :notifications, [ :expires_at ]
    add_index :notifications, [ :priority, :created_at ]
  end
end
