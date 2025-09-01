# frozen_string_literal: true

module Agents
  module Tools
    class DdgSearchTool
      extend Langchain::ToolDefinition
      
      NAME = "web_search"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/web_search_tool.json").to_s
      
      def self.description
        <<~DESC
        Search the web for current information using DuckDuckGo. Use this when you need up-to-date information,
        facts, news, or any information that might have changed after your knowledge cutoff.
        DESC
      end
      
      # Define the web_search function with parameters
      define_function :execute, description: "Search the web for current information" do
        property :query, type: "string", description: "Search query", required: true
        property :num_results, type: "integer", description: "Number of results to return", required: false
      end
      
      def initialize
        # No API key needed for DuckDuckGo
      end
      
      # Perform a web search using DuckDuckGo HTML version
      def execute(query:, num_results: 5)
        return { error: "No query provided" } if query.blank?
        
        require 'net/http'
        require 'uri'
        require 'nokogiri'
        
        # Use DuckDuckGo HTML search
        uri = URI('https://html.duckduckgo.com/html/')
        
        # Make POST request with query
        response = Net::HTTP.post_form(uri, { 'q' => query })
        
        if response.code != '200'
          return { error: "Search failed: HTTP #{response.code}" }
        end
        
        # Parse HTML response
        doc = Nokogiri::HTML(response.body)
        
        # Extract search results
        results = []
        doc.css('.result').first(num_results).each do |result|
          title_elem = result.css('.result__title')
          link_elem = result.css('.result__url')
          snippet_elem = result.css('.result__snippet')
          
          next if title_elem.empty? || link_elem.empty?
          
          # Extract URL from the DuckDuckGo redirect
          link_text = link_elem.text.strip
          actual_link = if link_text.start_with?('http')
                          link_text
                        else
                          "https://#{link_text}"
                        end
          
          # Extract source domain safely
          source = begin
            URI.parse(actual_link).host
          rescue
            link_text
          end
          
          results << {
            title: title_elem.text.strip,
            link: actual_link,
            snippet: snippet_elem.text.strip,
            source: source
          }
        end
        
        {
          success: true,
          query: query,
          results: results,
          total_results: results.length
        }
      rescue => e
        { error: "Search failed: #{e.message}" }
      end
    end
  end
end