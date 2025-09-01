# frozen_string_literal: true

class ProcessKnowledgeDocumentJob < ApplicationJob
  queue_as :default
  
  def perform(knowledge_document_id)
    document = KnowledgeDocument.find(knowledge_document_id)
    
    # Broadcast processing started
    broadcast_update(document, "Processing document...", "processing")
    
    # Process the document (extract text and generate embeddings)
    DocumentProcessorService.new(document).process!
    
    # Broadcast completion
    broadcast_update(document, "Document processed successfully!", "completed")
    
    # Send completion notification
    send_completion_notification(document)
    
    Rails.logger.info "Successfully processed knowledge document: #{document.title}"
  rescue => e
    Rails.logger.error "Failed to process knowledge document #{knowledge_document_id}: #{e.message}"
    
    # Broadcast error
    if document
      broadcast_error(document, "Processing failed: #{e.message}")
    end
    
    raise # Re-raise to trigger retry logic
  end
  
  private
  
  def broadcast_update(document, message, status)
    ActionCable.server.broadcast(
      "knowledge_document_#{document.id}",
      {
        type: "update",
        message: message,
        status: status,
        chunks_count: document.knowledge_chunks.count,
        processed_at: document.updated_at
      }
    )
  end
  
  def broadcast_error(document, message)
    ActionCable.server.broadcast(
      "knowledge_document_#{document.id}",
      {
        type: "error",
        message: message,
        status: "error"
      }
    )
  end
  
  def send_completion_notification(document)
    # Create a notification for the user
    Notification.create!(
      user: document.user,
      title: "Document processed successfully!",
      message: "The document '#{document.title}' has been processed and is ready for use in RAG searches.",
      notification_type: "success",
      action_url: Rails.application.routes.url_helpers.agents_knowledge_document_path(document),
      metadata: {
        knowledge_document_id: document.id,
        chunks_count: document.knowledge_chunks.count,
        processed_at: Time.current.iso8601
      }
    )
  end
end