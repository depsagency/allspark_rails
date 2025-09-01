# frozen_string_literal: true

# @label Data Table
class DataTableComponentPreview < Lookbook::Preview
  # @label Basic Table
  def default
    render Ui::DataTableComponent.new(
      data: sample_users,
      columns: [
        { key: :name, label: "Name" },
        { key: :email, label: "Email" },
        { key: :role, label: "Role" },
        { key: :status, label: "Status" }
      ]
    )
  end

  # @label Sortable Table (Visual Only)
  def sortable
    # Show a sorted table without interactive functionality
    sorted_data = sample_products.sort_by { |p| p[:name] }

    render Ui::DataTableComponent.new(
      data: sorted_data,
      columns: [
        { key: :name, label: "Product" },
        { key: :price, label: "Price", format: :currency },
        { key: :stock, label: "Stock", format: :number },
        { key: :category, label: "Category" }
      ],
      current_sort: "name",
      current_direction: "asc"
    )
  end

  # @label Table with Search (Visual Only)
  def searchable
    render Ui::DataTableComponent.new(
      data: sample_users,
      columns: [
        { key: :name, label: "Name" },
        { key: :email, label: "Email" },
        { key: :department, label: "Department" },
        { key: :status, label: "Status" }
      ],
      searchable: true,
      search_placeholder: "Search users..."
    ) do
      # Note: Search functionality requires proper Rails form handling
      # This preview shows the visual appearance only
    end
  end

  # @label Table with Formatting
  def formatted
    render Ui::DataTableComponent.new(
      data: sample_orders,
      columns: [
        { key: :order_id, label: "Order #" },
        { key: :customer, label: "Customer" },
        { key: :total, label: "Total", format: :currency, align: :right },
        { key: :date, label: "Date", format: :date },
        { key: :shipped, label: "Shipped", format: :boolean, align: :center }
      ]
    )
  end

  # @label Empty State
  def empty_state
    render Ui::DataTableComponent.new(
      data: [],
      columns: [
        { key: :name, label: "Name" },
        { key: :email, label: "Email" }
      ],
      empty_message: "No users found. Try adjusting your search criteria."
    )
  end

  # @label Loading State
  def loading_state
    render Ui::DataTableComponent.new(
      data: sample_users,
      columns: [
        { key: :name, label: "Name" },
        { key: :email, label: "Email" },
        { key: :role, label: "Role" }
      ],
      loading: true
    )
  end

  # @label Custom Table Classes
  def custom_styling
    render Ui::DataTableComponent.new(
      data: sample_users[0..2],
      columns: [
        { key: :name, label: "Name" },
        { key: :email, label: "Email" }
      ],
      table_class: "table table-compact table-zebra",
      css_class: "shadow-lg rounded-lg overflow-hidden"
    )
  end


  private

  def sample_users
    [
      {
        name: "John Doe",
        email: "john@example.com",
        role: "Admin",
        status: '<span class="badge badge-success">Active</span>'.html_safe,
        department: "Engineering"
      },
      {
        name: "Jane Smith",
        email: "jane@example.com",
        role: "User",
        status: '<span class="badge badge-success">Active</span>'.html_safe,
        department: "Marketing"
      },
      {
        name: "Bob Johnson",
        email: "bob@example.com",
        role: "Editor",
        status: '<span class="badge badge-warning">Pending</span>'.html_safe,
        department: "Sales"
      },
      {
        name: "Alice Brown",
        email: "alice@example.com",
        role: "User",
        status: '<span class="badge badge-error">Inactive</span>'.html_safe,
        department: "HR"
      }
    ]
  end

  def sample_products
    [
      { name: "MacBook Pro", price: 2499.99, stock: 15, category: "Electronics" },
      { name: "iPhone 15", price: 999.00, stock: 42, category: "Electronics" },
      { name: "AirPods Pro", price: 249.00, stock: 108, category: "Accessories" },
      { name: "iPad Air", price: 599.00, stock: 27, category: "Electronics" },
      { name: "Apple Watch", price: 399.00, stock: 63, category: "Wearables" }
    ]
  end

  def sample_orders
    [
      {
        order_id: "#10234",
        customer: "John Doe",
        total: 1299.99,
        date: Date.today - 2.days,
        shipped: true
      },
      {
        order_id: "#10235",
        customer: "Jane Smith",
        total: 549.50,
        date: Date.today - 1.day,
        shipped: true
      },
      {
        order_id: "#10236",
        customer: "Bob Johnson",
        total: 2199.00,
        date: Date.today,
        shipped: false
      },
      {
        order_id: "#10237",
        customer: "Alice Brown",
        total: 99.99,
        date: Date.today,
        shipped: false
      }
    ]
  end
end
