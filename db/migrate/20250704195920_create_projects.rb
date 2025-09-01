class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :projects, :name
    add_index :projects, [:user_id, :name], unique: true
  end
end
