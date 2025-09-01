# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

class AiModelGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  desc "Generates a Rails model with AI assistance for attributes and validations"

  class_option :description, type: :string, desc: "Description of what this model represents"
  class_option :attributes, type: :array, desc: "Model attributes (will be enhanced by AI if not provided)"
  class_option :provider, type: :string, desc: "AI provider to use (openai, claude, gemini)"
  class_option :skip_ai, type: :boolean, default: false, desc: "Skip AI enhancement"

  def create_model_with_ai
    if options[:skip_ai] || !ai_available?
      create_basic_model
    else
      create_ai_enhanced_model
    end
  end

  private

  def create_basic_model
    say "Creating basic model without AI enhancement..."
    invoke "model", [ name ] + (options[:attributes] || [])
  end

  def create_ai_enhanced_model
    say "Enhancing model generation with AI..."

    ai_response = generate_ai_suggestions
    if ai_response
      enhanced_attributes = parse_ai_response(ai_response)
      create_model_files(enhanced_attributes)
    else
      say "AI enhancement failed, falling back to basic model...", :yellow
      create_basic_model
    end
  end

  def generate_ai_suggestions
    prompt = build_ai_prompt

    begin
      adapter = Llm::AdapterFactory.create(options[:provider])
      adapter.generate(prompt, max_tokens: 1500, temperature: 0.3)
    rescue => e
      say "AI generation failed: #{e.message}", :red
      nil
    end
  end

  def build_ai_prompt
    description = options[:description] || "a #{name.humanize.downcase}"
    existing_attrs = (options[:attributes] || []).join(", ")

    <<~PROMPT
      I'm creating a Rails model called "#{name}" that represents #{description}.

      #{"Current attributes: #{existing_attrs}" if existing_attrs.present?}

      Please suggest:
      1. Appropriate database attributes with their types
      2. Validations for each attribute
      3. Any useful associations this model might have
      4. Any helpful scopes or class methods

      Respond in this exact JSON format:
      {
        "attributes": [
          {"name": "attribute_name", "type": "string|integer|boolean|text|decimal|datetime|etc", "required": true|false, "description": "purpose of this attribute"}
        ],
        "validations": [
          {"attribute": "attribute_name", "rules": ["presence", "uniqueness", "length: { minimum: 2 }", "etc"]}
        ],
        "associations": [
          {"type": "belongs_to|has_many|has_one", "name": "association_name", "class_name": "ClassName", "optional": true|false}
        ],
        "scopes": [
          {"name": "scope_name", "description": "what this scope does", "implementation": "lambda { where(...) }"}
        ]
      }

      Keep it practical and follow Rails conventions. Don't over-engineer.
    PROMPT
  end

  def parse_ai_response(response)
    # Extract JSON from the response (AI might include extra text)
    json_match = response.match(/\{.*\}/m)
    return nil unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    say "Failed to parse AI response: #{e.message}", :red
    nil
  end

  def create_model_files(enhanced_data)
    # Generate migration with AI-suggested attributes
    attributes_for_migration = enhanced_data["attributes"].map do |attr|
      "#{attr['name']}:#{attr['type']}"
    end

    invoke "model", [ name ] + attributes_for_migration

    # Enhance the generated model file
    enhance_model_file(enhanced_data)

    say "Model generated with AI enhancements!", :green
    display_suggestions(enhanced_data)
  end

  def enhance_model_file(enhanced_data)
    model_file = "app/models/#{file_name}.rb"
    return unless File.exist?(model_file)

    content = File.read(model_file)

    # Add validations
    validations = generate_validations(enhanced_data["validations"] || [])
    content = content.gsub(/^end$/, "#{validations}\nend")

    # Add associations
    associations = generate_associations(enhanced_data["associations"] || [])
    content = content.gsub(/^end$/, "#{associations}\nend") if associations.present?

    # Add scopes
    scopes = generate_scopes(enhanced_data["scopes"] || [])
    content = content.gsub(/^end$/, "#{scopes}\nend") if scopes.present?

    File.write(model_file, content)
  end

  def generate_validations(validations)
    return "" if validations.empty?

    validation_lines = validations.map do |validation|
      rules = validation["rules"].join(", ")
      "  validates :#{validation['attribute']}, #{rules}"
    end

    "\n  # Validations\n#{validation_lines.join("\n")}\n"
  end

  def generate_associations(associations)
    return "" if associations.empty?

    association_lines = associations.map do |assoc|
      options = []
      options << "class_name: '#{assoc['class_name']}'" if assoc["class_name"]
      options << "optional: true" if assoc["optional"]

      option_string = options.any? ? ", #{options.join(', ')}" : ""
      "  #{assoc['type']} :#{assoc['name']}#{option_string}"
    end

    "\n  # Associations\n#{association_lines.join("\n")}\n"
  end

  def generate_scopes(scopes)
    return "" if scopes.empty?

    scope_lines = scopes.map do |scope|
      "  scope :#{scope['name']}, #{scope['implementation']}"
    end

    "\n  # Scopes\n#{scope_lines.join("\n")}\n"
  end

  def display_suggestions(enhanced_data)
    say "\nAI Suggestions Applied:", :green

    enhanced_data["attributes"]&.each do |attr|
      say "  • #{attr['name']} (#{attr['type']}): #{attr['description']}", :cyan
    end

    if enhanced_data["associations"]&.any?
      say "\nSuggested Associations:", :yellow
      enhanced_data["associations"].each do |assoc|
        say "  • #{assoc['type']} :#{assoc['name']}"
      end
    end
  end

  def ai_available?
    Llm::AdapterFactory.available_providers.any?
  rescue
    false
  end
end
