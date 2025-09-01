# frozen_string_literal: true

module Agents
  class KnowledgeDocumentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_knowledge_document, only: [:show, :edit, :update, :destroy]
    before_action :set_assistants, only: [:new, :edit, :create, :update]
    
    def index
      # Base query for documents
      base_query = KnowledgeDocument.where(
        '(knowledge_documents.user_id = ?) OR (knowledge_documents.source_type IN (?, ?) AND knowledge_documents.user_id = (SELECT id FROM users WHERE email = ?))',
        current_user.id,
        'documentation',
        'code',
        'system@allspark.ai'
      ).includes(:assistant, :knowledge_chunks)
      
      # Filter by assistant if provided
      if params[:assistant_id].present?
        @assistant = current_user.assistants.find(params[:assistant_id])
        base_query = base_query.where(assistant: @assistant)
      end
      
      # Apply metadata filters
      filters = {}
      
      # Tag filtering
      if params[:tags].present?
        tags = params[:tags].is_a?(String) ? params[:tags].split(',').map(&:strip) : params[:tags]
        filters[:tags] = tags
        filters[:match_all_tags] = params[:match_all_tags].present?
      end
      
      # Category filtering
      if params[:category].present?
        filters[:category] = params[:category]
      end
      
      # Project filtering
      if params[:project].present?
        filters[:project] = params[:project]
      end
      
      # Visibility filtering
      if params[:visibility].present?
        filters[:visibility] = params[:visibility]
      end
      
      # Apply filters using advanced search if query or filters present
      if params[:query].present? || filters.any?
        @search_query = params[:query]
        
        # Use advanced search with metadata filters
        matching_docs = KnowledgeDocument.advanced_search(
          @search_query,
          filters,
          limit: 100,
          assistant: @assistant
        )
        
        # Update base query to only include matching documents
        if matching_docs.any?
          doc_ids = matching_docs.respond_to?(:pluck) ? matching_docs.pluck(:id) : matching_docs.map(&:id)
          base_query = base_query.where(id: doc_ids)
        else
          base_query = base_query.none
        end
      end
      
      # Get available filter options for UI
      @available_tags = base_query.all_tags
      @available_categories = base_query.all_categories
      @available_projects = base_query.all_projects
      
      # Calculate stats before pagination
      @total_documents = base_query.count
      @total_chunks = KnowledgeChunk.joins(:knowledge_document).merge(base_query).count
      @documents_by_type = base_query.group(:source_type).count
      
      # Apply ordering and pagination
      @knowledge_documents = base_query
        .order(created_at: :desc)
        .page(params[:page])
        .per(20)
      
      # Preload file attachments separately to avoid UUID casting issues
      ActiveRecord::Associations::Preloader.new(
        records: @knowledge_documents,
        associations: { file_attachment: :blob }
      ).call if @knowledge_documents.any?
    end
    
    def show
      @chunks = @knowledge_document.knowledge_chunks.order(:position)
    end
    
    def new
      @knowledge_document = current_user.knowledge_documents.build
      @knowledge_document.assistant_id = params[:assistant_id] if params[:assistant_id]
      set_available_metadata_options
    end
    
    def create
      @knowledge_document = current_user.knowledge_documents.build(knowledge_document_params)
      
      # If a file is uploaded but no content, set a placeholder
      if params[:knowledge_document][:file].present? && @knowledge_document.content.blank?
        @knowledge_document.content = "[File content will be extracted]"
      end
      
      if @knowledge_document.save
        # Process the document in the background if a file is attached
        if @knowledge_document.file.attached?
          ProcessKnowledgeDocumentJob.perform_later(@knowledge_document.id)
          flash[:notice] = "Document uploaded successfully. Processing in background..."
        else
          flash[:notice] = "Document created successfully."
        end
        redirect_to agents_knowledge_document_path(@knowledge_document)
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
      set_available_metadata_options
    end
    
    def update
      if @knowledge_document.update(knowledge_document_params)
        # Reprocess if file changed
        if @knowledge_document.file.attached? && @knowledge_document.file.blob.saved_changes?
          ProcessKnowledgeDocumentJob.perform_later(@knowledge_document.id)
          flash[:notice] = "Document updated. Reprocessing in background..."
        else
          flash[:notice] = "Document updated successfully."
        end
        redirect_to agents_knowledge_document_path(@knowledge_document)
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @knowledge_document.destroy
      flash[:notice] = "Document deleted successfully."
      redirect_to agents_knowledge_documents_path
    end
    
    private
    
    def set_knowledge_document
      # Allow access to both user's documents and system-imported documentation/code
      @knowledge_document = KnowledgeDocument.where(
        '(knowledge_documents.user_id = ?) OR (knowledge_documents.source_type IN (?, ?) AND knowledge_documents.user_id = (SELECT id FROM users WHERE email = ?))',
        current_user.id,
        'documentation',
        'code',
        'system@allspark.ai'
      ).find(params[:id])
    end
    
    def set_assistants
      @assistants = current_user.assistants.active.order(:name)
    end
    
    def knowledge_document_params
      # Base parameters
      permitted_params = params.require(:knowledge_document).permit(
        :title, :content, :assistant_id, :file, :source_type, :source_url,
        :category, :project, :visibility, :priority,
        tags: [], related_document_ids: []
      )
      
      # Handle custom attributes separately to allow dynamic keys
      if params[:knowledge_document][:custom_attributes].present?
        permitted_params[:custom_attributes] = params[:knowledge_document][:custom_attributes].to_unsafe_h
      end
      
      # Convert tags from comma-separated string if needed
      if params[:knowledge_document][:tags_string].present?
        permitted_params[:tags] = params[:knowledge_document][:tags_string].split(',').map(&:strip)
      end
      
      # Build metadata hash from individual fields
      metadata = permitted_params.extract!(:tags, :category, :project, :visibility, :priority, :custom_attributes, :related_document_ids)
      
      # Only add metadata fields that are present
      unless metadata.empty?
        existing_metadata = @knowledge_document&.metadata || {}
        permitted_params[:metadata] = existing_metadata.merge(metadata.compact)
      end
      
      permitted_params
    end
    
    def set_available_metadata_options
      # Get available options from all knowledge documents accessible to the user
      scope = KnowledgeDocument.where(
        '(knowledge_documents.user_id = ?) OR (knowledge_documents.source_type IN (?, ?) AND knowledge_documents.user_id = (SELECT id FROM users WHERE email = ?))',
        current_user.id,
        'documentation',
        'code',
        'system@allspark.ai'
      )
      
      @available_categories = scope.all_categories
      @available_projects = scope.all_projects
      @available_tags = scope.all_tags
    end
  end
end