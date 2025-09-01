# frozen_string_literal: true

# DataTable component with sorting, filtering, and pagination
#
# Provides a full-featured data table with:
# - Column sorting
# - Search and filtering
# - Responsive design
# - Action buttons
# - Pagination integration
#
# Example usage:
#   <%= render Ui::DataTableComponent.new(
#         data: @users,
#         columns: [
#           { key: :name, label: "Name", sortable: true },
#           { key: :email, label: "Email", sortable: true },
#           { key: :created_at, label: "Created", sortable: true, format: :date }
#         ],
#         searchable: true,
#         per_page: 25
#       ) do |table| %>
#     <% table.with_action_column do |user| %>
#       <%= link_to "Edit", edit_user_path(user), class: "btn btn-sm btn-primary" %>
#     <% end %>
#   <% end %>
#
class Ui::DataTableComponent < BaseComponent
  include Kaminari::Helpers::HelperMethods if defined?(Kaminari)

  option :data, reader: :private
  option :columns, default: -> { [] }
  option :searchable, default: -> { false }
  option :search_placeholder, default: -> { "Search..." }
  option :search_value, optional: true
  option :sortable, default: -> { true }
  option :current_sort, optional: true
  option :current_direction, default: -> { "asc" }
  option :per_page, optional: true
  option :css_class, optional: true
  option :table_class, default: -> { "table table-zebra" }
  option :empty_message, default: -> { "No records found" }
  option :loading, default: -> { false }

  renders_one :action_column, lambda { |&block|
    @action_column_block = block
    ""
  }

  renders_one :empty_state, lambda { |&block|
    @empty_state_block = block
    ""
  }

  private

  def table_data
    @table_data ||= begin
      result = data
      result = result.page(current_page) if paginated?
      result = result.per(per_page) if paginated? && per_page
      result
    end
  end

  def current_page
    params[:page] || 1
  end

  def paginated?
    defined?(Kaminari) && data.respond_to?(:page)
  end

  def container_classes
    classes = [ "overflow-x-auto" ]
    classes << css_class if css_class.present?
    classes.join(" ")
  end

  def table_classes
    classes = [ table_class ]
    classes << "table-pin-rows" if has_header?
    classes.join(" ")
  end

  def has_header?
    columns.any?
  end

  def has_actions?
    @action_column_block.present?
  end

  def has_search?
    searchable
  end

  def has_data?
    table_data.present? && table_data.any?
  end

  def search_form_id
    @search_form_id ||= "search-form-#{SecureRandom.hex(4)}"
  end

  def sort_url(column_key)
    return "#" unless sortable && column_sortable?(column_key)

    direction = if current_sort == column_key.to_s
                  current_direction == "asc" ? "desc" : "asc"
    else
                  "asc"
    end

    url_for(params.permit!.merge(sort: column_key, direction: direction))
  end

  def column_sortable?(column_key)
    column = columns.find { |col| col[:key] == column_key }
    column && column.fetch(:sortable, false)
  end

  def sort_icon(column_key)
    return "" unless column_sortable?(column_key)

    if current_sort == column_key.to_s
      if current_direction == "asc"
        "↑"
      else
        "↓"
      end
    else
      "↕"
    end
  end

  def column_header_classes(column)
    classes = []
    classes << "cursor-pointer" if column_sortable?(column[:key])
    classes << "text-right" if column[:align] == :right
    classes << "text-center" if column[:align] == :center
    classes.join(" ")
  end

  def cell_classes(column)
    classes = []
    classes << "text-right" if column[:align] == :right
    classes << "text-center" if column[:align] == :center
    classes.join(" ")
  end

  def format_cell_value(value, column)
    return "" if value.nil?

    case column[:format]
    when :date
      value.respond_to?(:strftime) ? value.strftime("%m/%d/%Y") : value
    when :datetime
      value.respond_to?(:strftime) ? value.strftime("%m/%d/%Y %I:%M %p") : value
    when :currency
      number_to_currency(value)
    when :number
      number_with_delimiter(value)
    when :percentage
      number_to_percentage(value, precision: 1)
    when :boolean
      value ? "✓" : "✗"
    else
      if column[:block]
        column[:block].call(value)
      else
        value.to_s
      end
    end
  end

  def cell_value(record, column)
    key = column[:key]

    if key.is_a?(Proc)
      key.call(record)
    elsif record.respond_to?(key)
      record.send(key)
    elsif record.is_a?(Hash)
      record[key] || record[key.to_s]
    else
      ""
    end
  end

  def loading_row_count
    per_page || 10
  end

  # Helper methods for number formatting
  def number_to_currency(value)
    return "" if value.nil?
    "$#{sprintf('%.2f', value)}"
  end

  def number_with_delimiter(value)
    return "" if value.nil?
    value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def number_to_percentage(value, options = {})
    return "" if value.nil?
    precision = options[:precision] || 0
    "#{sprintf("%.#{precision}f", value)}%"
  end
end
