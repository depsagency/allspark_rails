# frozen_string_literal: true

namespace :agents do
  desc "Test AI Agent setup"
  task test_setup: :environment do
    puts "Testing AI Agent Setup..."
    puts "=" * 50
    
    # Test 1: Check if LangChain gems are loaded
    print "1. Checking LangChain gems... "
    begin
      require 'langchainrb'
      require 'langchainrb_rails'
      puts "✓ Loaded successfully"
    rescue LoadError => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 2: Check if models exist
    print "2. Checking Assistant model... "
    begin
      Assistant.new
      puts "✓ Model exists"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    print "3. Checking AssistantMessage model... "
    begin
      AssistantMessage.new
      puts "✓ Model exists"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 3: Check LLM adapter
    print "4. Testing LLM adapter... "
    begin
      client = Llm::Client.with_fallback
      adapter = Llm::LangchainAdapter.new(client)
      llm = adapter.to_langchain_llm
      puts "✓ Adapter created"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 4: Create a test assistant
    print "5. Creating test assistant... "
    begin
      assistant = Assistant.create!(
        name: "Test Assistant",
        instructions: "You are a test assistant",
        tool_choice: "auto"
      )
      puts "✓ Created: #{assistant.id}"
      
      # Clean up
      assistant.destroy
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    puts "=" * 50
    puts "Setup test complete!"
  end
  
  desc "Create a sample chat bot assistant"
  task create_chat_bot: :environment do
    assistant = Assistant.find_or_create_by(name: 'Chat Bot Assistant') do |asst|
      asst.instructions = <<~INSTRUCTIONS
        You are a helpful AI assistant integrated into a chat system.
        Be friendly, concise, and helpful in your responses.
        You can help users with questions, provide information, and assist with tasks.
        Always maintain a professional and respectful tone.
      INSTRUCTIONS
      
      asst.tools = [
        { type: 'calculator' },
        { type: 'ruby_code_interpreter' }
      ]
      
      asst.tool_choice = 'auto'
      asst.active = true
    end
    
    puts "Created assistant: #{assistant.name} (ID: #{assistant.id})"
  end
  
  desc "Test chat agent integration"
  task test_chat: :environment do
    # Find or create test user
    user = User.find_by(email: 'test@example.com') || User.create!(
      email: 'test@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User'
    )
    
    # Create a test thread
    thread = ChatThread.create!(
      name: 'AI Test Thread',
      created_by: user
    )
    thread.add_participant(user)
    
    # Enable agent
    thread.metadata = { 'agent_enabled' => true }
    thread.save!
    
    puts "Created test thread: #{thread.name} (ID: #{thread.id})"
    puts "Agent enabled: #{thread.metadata['agent_enabled']}"
    puts "\nYou can now test the chat at: /chat/threads/#{thread.id}"
  end
end