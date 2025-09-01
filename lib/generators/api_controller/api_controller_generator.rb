# frozen_string_literal: true

class ApiControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_controller_file
    template "controller.rb.erb", "app/controllers/api/#{file_name.pluralize}_controller.rb"
  end

  def create_test_file
    template "controller_test.rb.erb", "test/controllers/api/#{file_name.pluralize}_controller_test.rb"
  end

  private

  def class_name
    name.camelize
  end

  def plural_class_name
    class_name.pluralize
  end

  def plural_file_name
    file_name.pluralize
  end
end
