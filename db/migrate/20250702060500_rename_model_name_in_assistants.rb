class RenameModelNameInAssistants < ActiveRecord::Migration[8.0]
  def change
    rename_column :assistants, :model_name, :llm_model_name
  end
end