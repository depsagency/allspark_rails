# frozen_string_literal: true

module Agents
  module Tools
    class RagTool
      extend Langchain::ToolDefinition
      
      NAME = "knowledge_search"
      ANNOTATIONS_PATH = Pathname.new(__dir__).join("../../../schemas/agents/tools/rag_tool.json").to_s
      
      def self.description
        <<~DESC
        Search the internal knowledge base for information about companies, products, people, or any stored knowledge.
        Use this tool FIRST when asked about specific entities, organizations, or topics that might be documented.
        This searches through uploaded documents, reference materials, and curated knowledge about known entities.
      DESC
      end
      
      # Define the knowledge_search function with parameters
      define_function :execute, description: "Search internal knowledge base for information about companies, people, products or stored documents. Use this FIRST for queries about specific entities." do
        property :query, type: "string", description: "Search query - company names, product names, people, or topics", required: true
        property :limit, type: "integer", description: "Maximum number of results (default: 5)", required: false
      end
      
      def initialize(assistant: nil)
        @assistant = assistant
      end
      
      # Search the knowledge base
      def execute(query:, limit: 5)
        return { error: "No query provided" } if query.blank?
        
        # Search for relevant chunks
        search_results = KnowledgeChunk.search(query, limit: limit * 2, assistant: @assistant)
        
        # Extract chunks from search results and group by document
        chunks_by_doc = {}
        search_results.each do |result|
          chunk = result[:chunk]
          doc = chunk.knowledge_document
          chunks_by_doc[doc] ||= []
          chunks_by_doc[doc] << chunk
        end
        
        # Format results
        results = chunks_by_doc.map do |doc, doc_chunks|
          {
            document: {
              id: doc.id,
              title: doc.title,
              source: doc.source_type
            },
            chunks: doc_chunks.map do |chunk|
              {
                content: chunk.content,
                position: chunk.position,
                context: get_chunk_context(chunk)
              }
            end
          }
        end.first(limit)
        
        {
          success: true,
          query: query,
          results: results,
          count: results.size
        }
      rescue => e
        { error: "Knowledge search failed: #{e.message}" }
      end
      
      private
      
      def get_chunk_context(chunk)
        # Get surrounding chunks for better context
        context_chunks = chunk.context(before: 1, after: 1)
        context_chunks.map(&:content).join("\n\n")
      end
    end
  end
end