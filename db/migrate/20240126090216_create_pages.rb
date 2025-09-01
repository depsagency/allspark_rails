class CreatePages < ActiveRecord::Migration[7.1]
  def change
    create_table :pages, id: :uuid do |t|
      t.string :title
      t.text :content

      t.timestamps
    end
  end
end
