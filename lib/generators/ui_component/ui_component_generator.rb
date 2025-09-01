# frozen_string_literal: true

class UiComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  desc "Generate a ViewComponent with DaisyUI styling and Lookbook preview"

  class_option :namespace, type: :string, default: "Ui", desc: "Component namespace (default: Ui)"
  class_option :variants, type: :array, default: %w[primary secondary], desc: "Component variants"
  class_option :with_stimulus, type: :boolean, default: false, desc: "Include Stimulus controller"
  class_option :skip_preview, type: :boolean, default: false, desc: "Skip Lookbook preview generation"
  class_option :skip_test, type: :boolean, default: false, desc: "Skip test file generation"

  def create_component_file
    @namespace = options[:namespace]
    @component_name = "#{class_name}Component"
    @full_component_name = "#{@namespace}::#{@component_name}"
    @variants = options[:variants].is_a?(Array) ? options[:variants] : options[:variants].split(",").map(&:strip)
    @with_stimulus = options[:with_stimulus]

    template(
      "component.rb.tt",
      File.join("app/components", namespace_path, "#{file_name}_component.rb")
    )
  end

  def create_template_file
    template(
      "component.html.erb.tt",
      File.join("app/components", namespace_path, "#{file_name}_component.html.erb")
    )
  end

  def create_stimulus_controller
    return unless @with_stimulus

    template(
      "stimulus_controller.js.tt",
      File.join("app/javascript/controllers", "#{file_name}_component_controller.js")
    )
  end

  def create_preview_file
    return if options[:skip_preview]

    template(
      "preview.rb.tt",
      File.join("app/components/previews", "#{file_name}_component_preview.rb")
    )
  end

  def create_test_file
    return if options[:skip_test]

    template(
      "component_spec.rb.tt",
      File.join("spec/components", namespace_path, "#{file_name}_component_spec.rb")
    )
  end

  def show_usage_instructions
    say ""
    say "Component generated successfully!", :green
    say ""
    say "Files created:", :blue
    say "  • app/components/#{namespace_path}/#{file_name}_component.rb"
    say "  • app/components/#{namespace_path}/#{file_name}_component.html.erb"
    say "  • app/components/previews/#{file_name}_component_preview.rb" unless options[:skip_preview]
    say "  • spec/components/#{namespace_path}/#{file_name}_component_spec.rb" unless options[:skip_test]
    say "  • app/javascript/controllers/#{file_name}_component_controller.js" if @with_stimulus
    say ""
    say "Usage in views:", :blue
    say "  <%= render #{@full_component_name}.new %>"
    say ""
    unless options[:skip_preview]
      say "Preview available at:", :blue
      say "  http://localhost:3000/lookbook"
    end
    say ""
  end

  private

  def namespace_path
    @namespace.underscore
  end

  def stimulus_controller_name
    "#{file_name.gsub('_', '-')}-component"
  end
end
