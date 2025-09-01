# frozen_string_literal: true

module Llm
  class LogoGeneratorService
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Validation error class
    class LogoGenerationError < StandardError; end

    # Logo specifications from docs/logo-replacement.md
    LOGO_SPECS = {
      width: 150,
      height: 40,
      aspect_ratio: "3:1 to 4:1",
      format: "PNG with transparency",
      max_file_size: 50.kilobytes
    }.freeze

    attribute :app_project
    attribute :provider, default: "openai"

    validates :app_project, presence: true
    validate :prd_must_exist

    def initialize(app_project:, provider: nil)
      @app_project = app_project
      @provider = provider || "openai"
    end

    def generate
      validate!

      ai_generation = create_generation_record

      begin
        prompt = ai_generation.input_prompt

        # Call image generation API
        result = call_image_provider(prompt)

        if result.is_a?(Hash) && result[:url].present?
          Rails.logger.info "Attempting to download image from URL (first 100 chars): #{result[:url][0..100]}"

          # Download and store the image
          downloaded_file = download_and_store_image(result)

          if downloaded_file
            Rails.logger.info "Image successfully downloaded and stored"
            # Process successful generation
            process_successful_generation(ai_generation, result, downloaded_file)
            # Clean up the temp file after successful processing
            downloaded_file.close rescue nil
            downloaded_file.unlink if downloaded_file.respond_to?(:unlink) rescue nil
            true
          else
            Rails.logger.error "Failed to download image from result"
            # Handle download failure
            process_failed_generation(ai_generation, "Failed to download generated image")
            false
          end
        else
          # Handle generation failure
          error_msg = result.is_a?(Hash) ? "Image generation returned no URL" : "Image generation returned invalid result"
          process_failed_generation(ai_generation, error_msg)
          false
        end

      rescue => e
        process_failed_generation(ai_generation, e.message)
        false
      end
    end

    private

    attr_reader :app_project, :provider

    def validate!
      raise LogoGenerationError, "App project is required" unless app_project
      raise LogoGenerationError, "PRD must be generated before creating logo" unless app_project.generated_prd.present?
    end

    def prd_must_exist
      errors.add(:app_project, "must have a generated PRD") unless app_project&.generated_prd&.present?
    end

    def create_generation_record
      prompt = build_logo_prompt
      app_project.ai_generations.create!(
        generation_type: "logo",
        llm_provider: provider,
        status: "pending",
        input_prompt: prompt,
        raw_output: nil
      )
    end

    def build_logo_prompt
      app_type = determine_app_type
      style_template = get_style_template(app_type)
      brand_traits = determine_brand_personality

      # Optimize prompt for DALL-E 3's improved capabilities
      <<~PROMPT
        Create a single logo mark for a #{app_type} application.

        #{style_template}

        Requirements:
        - ONE symbol only (no text, no variations, no multiple options)
        - Square format on transparent background
        - Simple, clean, geometric design
        - 2 colors maximum
        - Website-ready (no mockups or presentations)

        Style: #{brand_traits.truncate(25)}
      PROMPT
    end

    def extract_key_info_from_prd
      prd_content = app_project.generated_prd
      return "No PRD available" unless prd_content.present?

      # Extract first paragraph or executive summary
      first_section = prd_content.split("\n\n").first

      # Look for executive summary specifically
      if prd_content.match(/(?:executive summary|overview)[\s\S]*?(?=##|$)/i)
        first_section = $&.strip.gsub(/^#+\s*/, "") # Remove markdown headers
      end

      first_section.truncate(150)
    end

    def determine_brand_personality
      traits = []

      # Quick analysis of design response
      if app_project.design_response.present?
        text = app_project.design_response.downcase
        traits << "modern" if text.match?(/modern|sleek|contemporary/)
        traits << "professional" if text.match?(/professional|corporate|business/)
        traits << "friendly" if text.match?(/friendly|approachable|warm/)
      end

      # Default fallback
      traits << "professional" if traits.empty?

      traits.join(", ")
    end

    def determine_app_type
      # Analyze PRD and responses to determine app category
      content = [
        app_project.vision_response,
        app_project.features_response,
        app_project.generated_prd
      ].compact.join(" ").downcase

      return :fintech if content.match?(/payment|finance|bank|money|transaction|stripe|paypal/)
      return :productivity if content.match?(/task|project|manage|organize|workflow|notion|todoist/)
      return :saas if content.match?(/software|service|platform|api|dashboard|analytics/)
      return :ecommerce if content.match?(/shop|store|product|cart|buy|sell|marketplace/)
      return :social if content.match?(/social|community|chat|message|connect|network/)
      return :health if content.match?(/health|medical|fitness|doctor|patient|wellness/)
      return :education if content.match?(/learn|education|course|student|teach|training/)

      :general # Default fallback
    end

    def get_style_template(app_type)
      case app_type
      when :fintech
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Stripe mark: Simple parallel diagonal lines
        - Square mark: Rounded square shape
        - PayPal mark: Two overlapping P shapes
        - Use geometric shapes, trust colors (blue, green, black)
        TEMPLATE
      when :productivity
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Notion mark: Geometric N or cube shape
        - Linear mark: Simple arrow or line symbol
        - Todoist mark: Checkmark or checkbox symbol
        - Use clean geometric shapes, vibrant colors
        TEMPLATE
      when :saas
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Vercel mark: Triangle or arrow pointing up
        - Figma mark: Overlapping geometric shapes
        - GitHub mark: Octopus or geometric pattern
        - Use tech symbols, modern colors
        TEMPLATE
      when :ecommerce
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Shopify mark: Shopping bag or cart symbol
        - Amazon mark: Curved arrow or smile
        - Etsy mark: Simple house or craft symbol
        - Use friendly symbols, approachable colors
        TEMPLATE
      when :social
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Discord mark: Chat bubble or game controller
        - Twitter mark: Bird silhouette or wing shape
        - LinkedIn mark: Square with "in" or connection symbol
        - Use social symbols, friendly colors (blue, purple)
        TEMPLATE
      else
        <<~TEMPLATE
        REFERENCE MARKS - Create symbols like these (SYMBOL ONLY):
        - Simple geometric shapes: circle, triangle, square
        - Abstract symbols: lines, curves, dots
        - Minimal icons: arrow, star, diamond
        - Use clean geometry, professional colors
        TEMPLATE
      end
    end

    def call_image_provider(prompt)
      case provider
      when "openai"
        call_openai_dalle(prompt)
      else
        raise LogoGenerationError, "Unsupported image provider: #{provider}"
      end
    end


    def call_openai_dalle(prompt)
      api_key = ENV["OPENAI_API_KEY"]
      raise LogoGenerationError, "OpenAI API key not configured" if api_key.blank?

      adapter = Llm::OpenaiImageAdapter.new(
        api_key: api_key,
        model: "gpt-image-1" # Use GPT-image-1 for image generation
      )

      Rails.logger.info "Generating logo with GPT-image-1, prompt length: #{prompt.length}"

      start_time = Time.current
      result = adapter.generate_image(
        prompt,
        size: "1024x1024" # Square format for logo marks
      )
      processing_time = Time.current - start_time

      Rails.logger.debug "Logo generation result: #{result.inspect}"

      return nil unless result.is_a?(Hash) && result[:url].present?

      Rails.logger.info "Logo generation successful, processing time: #{processing_time}s"

      {
        url: result[:url],
        revised_prompt: result[:revised_prompt] || prompt,
        model: result[:model] || @model,
        cost: result[:cost] || 0.04,
        processing_time: processing_time,
        size: result[:size] || "1024x1024"
      }
    end

    def download_and_store_image(result)
      return nil unless result.is_a?(Hash) && result[:url].present?

      Rails.logger.info "download_and_store_image called with URL type: #{result[:url][0..50]}"

      adapter = Llm::OpenaiImageAdapter.new
      filename = "#{app_project.slug}-logo-#{Time.current.to_i}"

      # The URL might be base64 data or a regular URL
      downloaded_file = adapter.download_image(result[:url], filename)

      unless downloaded_file
        Rails.logger.error "adapter.download_image returned nil"
        return nil
      end

      Rails.logger.info "Downloaded file successfully, attaching to Active Storage"

      # Ensure file is at the beginning
      downloaded_file.rewind

      # Attach to app_project via Active Storage
      Rails.logger.info "Attaching file: #{filename}.png, size: #{downloaded_file.size} bytes"

      # Ensure file is readable and has content
      downloaded_file.rewind
      file_size = downloaded_file.size
      if file_size == 0
        raise "Downloaded file is empty"
      end

      # Create attachment - Active Storage in Rails 8 may be asynchronous
      begin
        # Create the attachment
        app_project.generated_logo.attach(
          io: downloaded_file,
          filename: "#{filename}.png",
          content_type: "image/png"
        )

        Rails.logger.info "File attachment initiated successfully for #{filename}.png"

        # In Rails 8, Active Storage attachment may be processed asynchronously
        # The AnalyzeJob that runs afterward indicates success
        # Trust that the attachment worked since we see the AnalyzeJob in logs

      rescue => e
        Rails.logger.error "Error during attachment process: #{e.message}"
        raise "Active Storage attachment failed: #{e.message}"
      end

      # Store the image data for immediate display
      url_to_store = result[:url]
      if url_to_store.start_with?("data:image")
        # Already a data URL, extract base64 part
        base64_data = url_to_store.split(",")[1]
        data_url = url_to_store
      elsif url_to_store.start_with?("iVBOR") || (!url_to_store.start_with?("http://") && !url_to_store.start_with?("https://"))
        # Raw base64 data
        base64_data = url_to_store
        data_url = "data:image/png;base64,#{url_to_store}"
      else
        # Regular URL, store as-is
        base64_data = nil
        data_url = url_to_store
      end

      # Store base64 data in the dedicated column and keep URL field for regular URLs only
      app_project.update!(
        logo_data: base64_data,
        generated_logo_url: base64_data ? nil : data_url
      )

      Rails.logger.info "Stored logo data - base64 length: #{base64_data&.length || 0}, URL: #{data_url&.truncate(50)}"

      # Return the downloaded file (caller is responsible for closing it)
      downloaded_file
    rescue => e
      Rails.logger.error "Failed to download and store image: #{e.message}"
      Rails.logger.error "Stack trace: #{e.backtrace.first(5).join("\n")}"
      # Clean up the file if an error occurred after downloading
      if downloaded_file
        downloaded_file.close rescue nil
        downloaded_file.unlink if downloaded_file.respond_to?(:unlink) rescue nil
      end
      nil
    end

    def process_successful_generation(ai_generation, result, downloaded_file)
      return unless result.is_a?(Hash)

      ai_generation.update!(
        status: "completed",
        raw_output: result[:revised_prompt] || app_project.logo_prompt || ai_generation.input_prompt,
        model_used: result[:model] || "unknown",
        cost: result[:cost] || 0.0,
        processing_time_seconds: result[:processing_time] || 0.0
      )

      app_project.update!(
        logo_prompt: ai_generation.input_prompt,
        logo_generation_metadata: {
          "generated_at" => Time.current.iso8601,
          "model" => result[:model] || "unknown",
          "cost" => result[:cost] || 0.0,
          "processing_time" => result[:processing_time] || 0.0,
          "original_url" => result[:url],
          "revised_prompt" => result[:revised_prompt],
          "size" => result[:size] || "1024x1024",
          "ai_generation_id" => ai_generation.id
        }
      )

      Rails.logger.info "Successfully generated logo for app_project #{app_project.id}"
    end

    def process_failed_generation(ai_generation, error_message)
      ai_generation.update!(
        status: "failed",
        error_message: error_message
      )

      Rails.logger.error "Logo generation failed for app_project #{app_project.id}: #{error_message}"
    end
  end
end
