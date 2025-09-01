class KnowledgeDocumentChannel < ApplicationCable::Channel
  def subscribed
    if params[:document_id].present?
      knowledge_document = KnowledgeDocument.find_by(id: params[:document_id])

      if knowledge_document && (knowledge_document.user_id == current_user.id || current_user.admin?)
        stream_from "knowledge_document_#{params[:document_id]}"

        # Send initial status
        transmit({
          type: "connected",
          status: knowledge_document.processing_status,
          chunks_count: knowledge_document.knowledge_chunks.count
        })
      else
        reject
      end
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def request_status(data)
    knowledge_document = KnowledgeDocument.find_by(id: data["document_id"])

    if knowledge_document && (knowledge_document.user_id == current_user.id || current_user.admin?)
      transmit({
        type: "status_update",
        status: knowledge_document.processing_status,
        chunks_count: knowledge_document.knowledge_chunks.count,
        processed_at: knowledge_document.updated_at
      })
    end
  end
end