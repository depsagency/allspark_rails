# frozen_string_literal: true

# @label Form Select
class SelectComponentPreview < Lookbook::Preview
  # @label Basic Select
  # @param label text "Select Label"
  # @param prompt text "Choose an option"
  # @param required toggle
  # @param disabled toggle
  def default(label: "Country", prompt: "Select a country", required: false, disabled: false)
    render Ui::Form::SelectComponent.new(
      name: "country",
      label: label,
      options: country_options,
      prompt: prompt,
      required: required,
      disabled: disabled
    )
  end

  # @label Select with Selected Value
  def with_selected
    render Ui::Form::SelectComponent.new(
      name: "priority",
      label: "Priority Level",
      options: priority_options,
      selected: "high",
      prompt: "Select priority"
    )
  end

  # @label Select with Error
  def with_error
    render Ui::Form::SelectComponent.new(
      name: "category",
      label: "Category",
      options: category_options,
      error: "Please select a category",
      prompt: "Choose category"
    )
  end

  # @label Select with Hint
  def with_hint
    render Ui::Form::SelectComponent.new(
      name: "timezone",
      label: "Time Zone",
      options: timezone_options,
      hint: "Select your local time zone",
      prompt: "Choose timezone"
    )
  end

  # @label Required Select
  def required
    render Ui::Form::SelectComponent.new(
      name: "department",
      label: "Department",
      options: department_options,
      required: true,
      prompt: "Select department"
    )
  end

  # @label Disabled Select
  def disabled
    render Ui::Form::SelectComponent.new(
      name: "readonly",
      label: "Read Only Select",
      options: [ [ "Fixed Value", "fixed" ] ],
      selected: "fixed",
      disabled: true
    )
  end

  # @label Select Sizes
  def sizes
    render Ui::Form::SelectComponent.new(
      name: "medium",
      label: "Medium Select (Default Size)",
      options: size_demo_options,
      size: "md"
    )
  end

  # @label Grouped Options
  def grouped_options
    render Ui::Form::SelectComponent.new(
      name: "product",
      label: "Product Selection",
      options: grouped_product_options,
      prompt: "Choose a product"
    )
  end

  private

  def country_options
    [
      [ "United States", "us" ],
      [ "Canada", "ca" ],
      [ "United Kingdom", "uk" ],
      [ "Germany", "de" ],
      [ "France", "fr" ],
      [ "Japan", "jp" ]
    ]
  end

  def priority_options
    [
      [ "Low", "low" ],
      [ "Medium", "medium" ],
      [ "High", "high" ],
      [ "Critical", "critical" ]
    ]
  end

  def category_options
    [
      [ "Electronics", "electronics" ],
      [ "Clothing", "clothing" ],
      [ "Books", "books" ],
      [ "Home & Garden", "home" ],
      [ "Sports", "sports" ]
    ]
  end

  def timezone_options
    [
      [ "Pacific Time (PT)", "PT" ],
      [ "Mountain Time (MT)", "MT" ],
      [ "Central Time (CT)", "CT" ],
      [ "Eastern Time (ET)", "ET" ]
    ]
  end

  def department_options
    [
      [ "Engineering", "engineering" ],
      [ "Marketing", "marketing" ],
      [ "Sales", "sales" ],
      [ "Human Resources", "hr" ],
      [ "Finance", "finance" ]
    ]
  end

  def size_demo_options
    [
      [ "Option 1", "1" ],
      [ "Option 2", "2" ],
      [ "Option 3", "3" ]
    ]
  end

  def grouped_product_options
    {
      "Electronics" => [
        [ "Laptop", "laptop" ],
        [ "Phone", "phone" ],
        [ "Tablet", "tablet" ]
      ],
      "Accessories" => [
        [ "Keyboard", "keyboard" ],
        [ "Mouse", "mouse" ],
        [ "Monitor", "monitor" ]
      ]
    }
  end
end
