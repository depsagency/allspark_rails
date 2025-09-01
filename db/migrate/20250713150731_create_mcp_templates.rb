class CreateMcpTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_templates, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :config_template, null: false
      t.jsonb :required_fields, default: []
      t.string :category
      t.string :icon_url
      t.string :documentation_url
      
      t.timestamps
    end
    
    add_index :mcp_templates, :key, unique: true
    add_index :mcp_templates, :category
  end
end
