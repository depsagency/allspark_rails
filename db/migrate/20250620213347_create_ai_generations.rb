class CreateAiGenerations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_generations, id: :uuid do |t|
      t.references :app_project, null: false, foreign_key: true, type: :uuid
      t.string :generation_type, null: false
      t.string :llm_provider, null: false
      t.string :model_used
      t.text :input_prompt, null: false
      t.text :raw_output
      t.integer :token_count
      t.decimal :cost, precision: 10, scale: 4
      t.float :processing_time_seconds
      t.string :status, default: 'pending'
      t.text :error_message

      t.timestamps
    end

    add_index :ai_generations, :generation_type
    add_index :ai_generations, :status
    add_index :ai_generations, :llm_provider
  end
end
