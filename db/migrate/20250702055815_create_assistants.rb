class CreateAssistants < ActiveRecord::Migration[8.0]
  def change
    create_table :assistants, id: :uuid do |t|
      t.string :name, null: false
      t.text :instructions
      t.string :tool_choice, default: 'auto'
      t.json :tools, default: []
      t.string :model_provider
      t.string :model_name
      t.boolean :active, default: true
      t.references :user, type: :uuid, foreign_key: true
      
      t.timestamps
    end

    add_index :assistants, :name
    add_index :assistants, :active
  end
end
