# frozen_string_literal: true

module Agents
  class KnowledgeSearchController < ApplicationController
    before_action :authenticate_user!
    before_action :set_assistants
    
    def index
      if params[:query].present?
        @query = params[:query]
        @assistant = current_user.assistants.find(params[:assistant_id]) if params[:assistant_id].present?
        
        # Search documents
        @document_results = search_documents
        
        # Search chunks
        @chunk_results = search_chunks
      end
    end
    
    private
    
    def set_assistants
      @assistants = current_user.assistants.active.order(:name)
    end
    
    def search_documents
      scope = current_user.knowledge_documents
      scope = scope.where(assistant: @assistant) if @assistant
      
      KnowledgeDocument.search(@query, limit: 5, assistant: @assistant)
    end
    
    def search_chunks
      KnowledgeChunk.search(@query, limit: 10, assistant: @assistant)
    end
  end
end