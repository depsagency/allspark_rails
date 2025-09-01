# frozen_string_literal: true

module Agents
  module Tools
    class WebSearchTool
      extend Langchain::ToolDefinition
      
      NAME = "web_search"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/web_search_tool.json").to_s
      
      def self.description
        <<~DESC
        Search the web for current information. Use this when you need up-to-date information,
        facts, news, or any information that might have changed after your knowledge cutoff.
      DESC
      end
      
      # Define the web_search function with parameters
      define_function :execute, description: "Search the web for current information" do
        property :query, type: "string", description: "Search query", required: true
        property :num_results, type: "integer", description: "Number of results to return", required: false
      end
      
      def initialize
        @api_key = ENV['GOOGLE_SEARCH_API_KEY']
        @search_engine_id = ENV['GOOGLE_SEARCH_ENGINE_ID'] || ENV['GOOGLE_CSE_ID']
      end
      
      # Perform a web search
      def execute(query:, num_results: 5)
        return { error: "No query provided" } if query.blank?
        return { error: "Google Search API key not configured" } unless @api_key
        return { error: "Google Search Engine ID not configured" } unless @search_engine_id
        
        require 'net/http'
        require 'uri'
        require 'json'
        
        uri = URI('https://www.googleapis.com/customsearch/v1')
        params = {
          key: @api_key,
          cx: @search_engine_id,
          q: query,
          num: num_results
        }
        uri.query = URI.encode_www_form(params)
        
        response = Net::HTTP.get_response(uri)
        
        if response.code != '200'
          error_data = JSON.parse(response.body) rescue {}
          error_message = error_data.dig('error', 'message') || "HTTP #{response.code}"
          return { error: "Search failed: #{error_message}" }
        end
        
        results = JSON.parse(response.body)
        
        {
          success: true,
          query: query,
          results: format_results(results),
          total_results: results['searchInformation']&.dig('totalResults')
        }
      rescue => e
        { error: "Search failed: #{e.message}" }
      end
      
      private
      
      def format_results(results)
        items = results['items'] || []
        
        items.first(5).map do |item|
          {
            title: item['title'],
            link: item['link'],
            snippet: item['snippet'],
            source: item['displayLink']
          }
        end
      end
    end
  end
end