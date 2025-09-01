# frozen_string_literal: true

# Taggable concern for flexible metadata management using JSONB
# Provides tagging, categorization, and custom attributes for any model with a metadata field
module Taggable
  extend ActiveSupport::Concern

  included do
    # Ensure metadata is always a hash
    after_initialize :ensure_metadata_hash
    before_save :clean_metadata
    
    # Scopes for tag-based queries
    scope :with_tag, ->(tag) { where("metadata->'tags' @> ?", [tag].to_json) }
    scope :with_any_tags, ->(tags) { where("metadata->'tags' ?| array[:tags]", tags: Array(tags)) }
    scope :with_all_tags, ->(tags) { where("metadata->'tags' @> ?", Array(tags).to_json) }
    scope :without_tags, ->(tags) { where.not("metadata->'tags' ?| array[:tags]", tags: Array(tags)) }
    
    # Scopes for category queries
    scope :in_category, ->(category) { where("metadata->>'category' = ?", category) }
    scope :in_categories, ->(categories) { where("metadata->>'category' IN (?)", Array(categories)) }
    
    # Scopes for project queries
    scope :for_project, ->(project) { where("metadata->>'project' = ?", project) }
    scope :for_projects, ->(projects) { where("metadata->>'project' IN (?)", Array(projects)) }
    
    # Scope for custom attribute queries
    scope :with_metadata, ->(key, value) { where("metadata->>? = ?", key.to_s, value.to_s) }
    scope :with_metadata_like, ->(key, pattern) { where("metadata->>? LIKE ?", key.to_s, "%#{pattern}%") }
    
    # Scope for visibility
    scope :visible_to, ->(visibility) { where("metadata->>'visibility' = ?", visibility) }
    scope :public_visibility, -> { visible_to('public') }
    scope :private_visibility, -> { visible_to('private') }
    scope :team_visibility, -> { visible_to('team') }
  end

  # Tag management methods
  def tags
    metadata['tags'] || []
  end

  def tags=(new_tags)
    metadata['tags'] = normalize_tags(new_tags)
  end

  def add_tag(tag)
    return if tag.blank?
    current_tags = tags
    normalized_tag = normalize_tag(tag)
    unless current_tags.include?(normalized_tag)
      metadata['tags'] = (current_tags + [normalized_tag]).uniq
    end
  end

  def add_tags(*new_tags)
    new_tags.flatten.compact.each { |tag| add_tag(tag) }
  end

  def remove_tag(tag)
    return if tag.blank?
    metadata['tags'] = tags - [normalize_tag(tag)]
  end

  def remove_tags(*tags_to_remove)
    tags_to_remove.flatten.compact.each { |tag| remove_tag(tag) }
  end

  def has_tag?(tag)
    tags.include?(normalize_tag(tag))
  end

  def has_any_tags?(*check_tags)
    check_tags.flatten.any? { |tag| has_tag?(tag) }
  end

  def has_all_tags?(*check_tags)
    check_tags.flatten.all? { |tag| has_tag?(tag) }
  end

  # Category management
  def category
    metadata['category']
  end

  def category=(new_category)
    metadata['category'] = new_category.presence
  end

  # Project management
  def project
    metadata['project']
  end

  def project=(new_project)
    metadata['project'] = new_project.presence
  end

  # Custom attributes management
  def custom_attributes
    metadata['custom_attributes'] || {}
  end

  def custom_attributes=(attrs)
    metadata['custom_attributes'] = attrs.is_a?(Hash) ? attrs : {}
  end

  def get_custom_attribute(key)
    custom_attributes[key.to_s]
  end

  def set_custom_attribute(key, value)
    attrs = custom_attributes
    attrs[key.to_s] = value
    metadata['custom_attributes'] = attrs
  end

  def remove_custom_attribute(key)
    attrs = custom_attributes
    attrs.delete(key.to_s)
    metadata['custom_attributes'] = attrs
  end

  # Visibility management
  def visibility
    metadata['visibility'] || 'private'
  end

  def visibility=(new_visibility)
    allowed_values = %w[public private team restricted]
    if allowed_values.include?(new_visibility.to_s)
      metadata['visibility'] = new_visibility.to_s
    end
  end

  def public?
    visibility == 'public'
  end

  def private?
    visibility == 'private'
  end

  def team?
    visibility == 'team'
  end

  def restricted?
    visibility == 'restricted'
  end

  # Priority/importance management
  def priority
    metadata['priority'] || 'normal'
  end

  def priority=(new_priority)
    allowed_values = %w[low normal high critical]
    if allowed_values.include?(new_priority.to_s)
      metadata['priority'] = new_priority.to_s
    end
  end

  # Related documents
  def related_document_ids
    metadata['related_documents'] || []
  end

  def related_document_ids=(ids)
    metadata['related_documents'] = Array(ids).compact.uniq
  end

  def add_related_document(document_id)
    ids = related_document_ids
    unless ids.include?(document_id)
      metadata['related_documents'] = ids + [document_id]
    end
  end

  def remove_related_document(document_id)
    metadata['related_documents'] = related_document_ids - [document_id]
  end

  # Metadata helpers
  def metadata_summary
    summary = {}
    summary[:tags] = tags if tags.any?
    summary[:category] = category if category.present?
    summary[:project] = project if project.present?
    summary[:visibility] = visibility
    summary[:priority] = priority if priority != 'normal'
    summary[:custom_attributes] = custom_attributes if custom_attributes.any?
    summary[:related_documents] = related_document_ids.size if related_document_ids.any?
    summary
  end

  # Search helpers
  def searchable_metadata_text
    parts = []
    parts << tags.join(' ') if tags.any?
    parts << category if category.present?
    parts << project if project.present?
    parts << custom_attributes.values.join(' ') if custom_attributes.any?
    parts.join(' ')
  end

  class_methods do
    # Class method to get all unique tags
    def all_tags
      pluck(Arel.sql("DISTINCT jsonb_array_elements_text(#{table_name}.metadata->'tags')"))
        .compact
        .uniq
        .sort
    rescue
      # Fallback for databases without jsonb_array_elements_text
      all.map(&:tags).flatten.uniq.sort
    end

    # Class method to get tag counts
    def tag_counts
      tags = all_tags
      counts = {}
      tags.each do |tag|
        counts[tag] = with_tag(tag).count
      end
      counts.sort_by { |_, count| -count }.to_h
    end

    # Class method to get all categories
    def all_categories
      pluck(Arel.sql("DISTINCT #{table_name}.metadata->>'category'"))
        .compact
        .uniq
        .sort
    end

    # Class method to get all projects
    def all_projects
      pluck(Arel.sql("DISTINCT #{table_name}.metadata->>'project'"))
        .compact
        .uniq
        .sort
    end

    # Advanced search with metadata
    def search_with_metadata(query, filters = {})
      scope = all
      
      # Apply tag filters
      if filters[:tags].present?
        tags = Array(filters[:tags])
        scope = filters[:match_all_tags] ? scope.with_all_tags(tags) : scope.with_any_tags(tags)
      end
      
      # Apply category filter
      if filters[:category].present?
        scope = scope.in_category(filters[:category])
      end
      
      # Apply project filter
      if filters[:project].present?
        scope = scope.for_project(filters[:project])
      end
      
      # Apply visibility filter
      if filters[:visibility].present?
        scope = scope.visible_to(filters[:visibility])
      end
      
      # Apply custom attribute filters
      if filters[:custom_attributes].present?
        filters[:custom_attributes].each do |key, value|
          scope = scope.with_metadata(key, value)
        end
      end
      
      scope
    end
  end

  private

  def ensure_metadata_hash
    self.metadata ||= {}
  end

  def clean_metadata
    # Remove empty arrays and nil values
    metadata.delete('tags') if metadata['tags'].blank?
    metadata.delete('category') if metadata['category'].blank?
    metadata.delete('project') if metadata['project'].blank?
    metadata.delete('custom_attributes') if metadata['custom_attributes'].blank?
    metadata.delete('related_documents') if metadata['related_documents'].blank?
  end

  def normalize_tags(tags_input)
    case tags_input
    when String
      tags_input.split(',').map { |t| normalize_tag(t) }.uniq
    when Array
      tags_input.map { |t| normalize_tag(t) }.uniq
    else
      []
    end
  end

  def normalize_tag(tag)
    tag.to_s.strip.downcase.gsub(/[^a-z0-9\-_]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
  end
end