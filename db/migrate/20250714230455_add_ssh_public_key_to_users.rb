class AddSshPublicKeyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ssh_public_key, :text
  end
end
