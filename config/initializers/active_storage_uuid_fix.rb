# frozen_string_literal: true

# Fix for ActiveStorage with UUID and integer primary keys
# This monkey patch ensures ActiveStorage works with both UUID and integer record_ids

Rails.application.config.to_prepare do
  # Fix attachment lookup to use string record_id
  ActiveStorage::Attached::One.class_eval do
    def attachment
      return nil unless record.persisted? && record.id.present?
      
      @attachment ||= ActiveStorage::Attachment.find_by(
        record_type: record.class.name,
        record_id: record.id.to_s,
        name: name
      )
    end
  end

  ActiveStorage::Attached::Many.class_eval do
    def attachments
      return ActiveStorage::Attachment.none unless record.persisted? && record.id.present?
      
      @attachments ||= ActiveStorage::Attachment.where(
        record_type: record.class.name,
        record_id: record.id.to_s,
        name: name
      )
    end
  end
  
  # Fix attachment creation to use string record_id
  ActiveStorage::Attachment.class_eval do
    before_save :ensure_string_record_id
    
    private
    
    def ensure_string_record_id
      self.record_id = record_id.to_s if record_id.present?
    end
  end
end