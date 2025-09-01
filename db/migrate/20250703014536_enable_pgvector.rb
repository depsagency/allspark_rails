class EnablePgvector < ActiveRecord::Migration[8.0]
  def up
    # Check if pgvector is available before trying to enable it
    result = execute("SELECT * FROM pg_available_extensions WHERE name = 'vector';")
    
    if result.any?
      enable_extension 'vector'
      Rails.logger.info "pgvector extension enabled successfully"
    else
      Rails.logger.warn "pgvector extension not available in PostgreSQL"
      Rails.logger.warn "RAG system will use text-based search instead of vector search"
    end
  end
  
  def down
    disable_extension 'vector' if extension_enabled?('vector')
  end
end