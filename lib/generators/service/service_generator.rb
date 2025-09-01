# frozen_string_literal: true

class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_service_file
    template "service.rb.erb", "app/services/#{file_name}_service.rb"
  end

  def create_test_file
    template "service_test.rb.erb", "test/services/#{file_name}_service_test.rb"
  end

  private

  def class_name
    "#{name.camelize}Service"
  end
end
