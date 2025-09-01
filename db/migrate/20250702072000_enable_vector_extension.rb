class EnableVectorExtension < ActiveRecord::Migration[8.0]
  def change
    # Skip if vector extension is not available
    # This migration is here for future use when pgvector is installed
    # enable_extension 'vector'
  end
end