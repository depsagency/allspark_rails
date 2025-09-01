# frozen_string_literal: true

namespace :agents do
  desc "Test complete AI agents setup"
  task test_complete: :environment do
    puts "Testing Complete AI Agents Setup"
    puts "=" * 50
    
    # Test 1: Create an assistant
    print "1. Creating test assistant... "
    begin
      user = User.first || User.create!(
        email: 'agent-test@example.com',
        password: 'password123'
      )
      
      assistant = Assistant.create!(
        name: "Test Agent #{Time.current.to_i}",
        instructions: "You are a helpful test assistant",
        tools: [
          { 'type' => 'calculator' },
          { 'type' => 'ruby_code' }
        ],
        tool_choice: 'auto',
        user: user
      )
      puts "✓ Created: #{assistant.name}"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 2: Test tools
    print "2. Testing calculator tool... "
    begin
      calc = Agents::Tools::CalculatorTool.new
      result = calc.execute(expression: "2 + 2")
      if result[:result] == 4
        puts "✓ Calculator works: 2 + 2 = #{result[:result]}"
      else
        puts "✗ Unexpected result: #{result}"
      end
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 3: Test Ruby code tool
    print "3. Testing Ruby code tool... "
    begin
      code_tool = Agents::Tools::RubyCodeTool.new
      result = code_tool.execute(code: "[1, 2, 3].sum")
      if result[:result] == 6
        puts "✓ Ruby code works: [1, 2, 3].sum = #{result[:result]}"
      else
        puts "✗ Unexpected result: #{result}"
      end
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 4: Health check
    print "4. Running health check... "
    begin
      health = Agents::HealthCheck.run
      puts "✓ System status: #{health[:status]}"
      
      health[:checks].each do |component, check|
        puts "   - #{component}: #{check[:status]}"
      end
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 5: Create a team
    print "5. Creating agent team... "
    begin
      team = AgentTeam.create!(
        name: "Test Team #{Time.current.to_i}",
        purpose: "Testing multi-agent coordination",
        user: user,
        assistants: [assistant]
      )
      puts "✓ Created team with #{team.assistants.count} agent(s)"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    # Test 6: Knowledge document (without embeddings)
    print "6. Creating knowledge document... "
    begin
      doc = KnowledgeDocument.create!(
        title: "Test Document",
        content: "This is a test document for the knowledge base.",
        source_type: "manual",
        user: user,
        assistant: assistant
      )
      puts "✓ Created document: #{doc.title}"
    rescue => e
      puts "✗ Failed: #{e.message}"
    end
    
    puts "=" * 50
    puts "Test complete!"
    puts "\nNext steps:"
    puts "1. Visit /agents/assistants to manage assistants"
    puts "2. Visit /agents/teams to manage teams"
    puts "3. Visit /agents/monitoring for system health"
    puts "4. Visit /integrations to connect external services"
  end
end