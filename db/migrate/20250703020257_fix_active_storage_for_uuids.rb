class FixActiveStorageForUuids < ActiveRecord::Migration[8.0]
  def up
    # Change record_id column to string type to support UUIDs
    # First remove the index that depends on this column
    remove_index :active_storage_attachments, column: [:record_type, :record_id, :name, :blob_id], if_exists: true
    
    # Change the column type
    change_column :active_storage_attachments, :record_id, :string
    
    # Recreate the index
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id], 
              name: "index_active_storage_attachments_uniqueness", unique: true
  end

  def down
    # Remove index
    remove_index :active_storage_attachments, column: [:record_type, :record_id, :name, :blob_id], if_exists: true
    
    # Revert back to bigint (this will fail if there are UUID values)
    change_column :active_storage_attachments, :record_id, :bigint
    
    # Recreate the index
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id], 
              name: "index_active_storage_attachments_uniqueness", unique: true
  end
end