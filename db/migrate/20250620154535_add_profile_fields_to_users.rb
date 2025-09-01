class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bio, :text
    add_column :users, :website, :string
    add_column :users, :twitter_handle, :string
    add_column :users, :linkedin_url, :string
    add_column :users, :github_username, :string
  end
end
