# frozen_string_literal: true

require 'test_helper'

class AssistantTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123'
    )
    @assistant = Assistant.create!(
      name: 'Test Assistant',
      instructions: 'You are a helpful assistant',
      tool_choice: 'auto',
      user: @user
    )
  end

  test "valid assistant" do
    assert @assistant.valid?
  end

  test "requires name" do
    @assistant.name = nil
    assert_not @assistant.valid?
    assert_includes @assistant.errors[:name], "can't be blank"
  end

  test "requires valid tool_choice" do
    @assistant.tool_choice = 'invalid'
    assert_not @assistant.valid?
    assert_includes @assistant.errors[:tool_choice], "is not included in the list"
  end

  test "tool_choice accepts valid values" do
    %w[auto none required].each do |choice|
      @assistant.tool_choice = choice
      assert @assistant.valid?
    end
  end

  test "has many assistant_messages" do
    assert_respond_to @assistant, :assistant_messages
  end

  test "has many agent_runs" do
    assert_respond_to @assistant, :agent_runs
  end

  test "has many knowledge_documents" do
    assert_respond_to @assistant, :knowledge_documents
  end

  test "belongs to user optionally" do
    @assistant.user = nil
    assert @assistant.valid?
  end

  test "active scope returns active assistants" do
    @assistant.update!(active: true)
    inactive = Assistant.create!(
      name: 'Inactive Assistant',
      active: false
    )
    
    active_assistants = Assistant.active
    assert_includes active_assistants, @assistant
    assert_not_includes active_assistants, inactive
  end

  test "configured_tools returns tool instances" do
    @assistant.tools = [
      { 'type' => 'calculator' },
      { 'type' => 'ruby_code' }
    ]
    
    tools = @assistant.send(:configured_tools)
    assert_equal 2, tools.size
    assert_instance_of Agents::Tools::CalculatorTool, tools[0]
    assert_instance_of Agents::Tools::RubyCodeTool, tools[1]
  end

  test "configured_tools handles unknown tool types" do
    @assistant.tools = [
      { 'type' => 'unknown_tool' }
    ]
    
    tools = @assistant.send(:configured_tools)
    assert_equal 0, tools.size
  end

  test "conversation_for_run returns messages for specific run" do
    run_id = SecureRandom.uuid
    message1 = @assistant.assistant_messages.create!(
      role: 'user',
      content: 'Hello',
      run_id: run_id
    )
    message2 = @assistant.assistant_messages.create!(
      role: 'assistant',
      content: 'Hi there',
      run_id: run_id
    )
    other_message = @assistant.assistant_messages.create!(
      role: 'user',
      content: 'Other',
      run_id: SecureRandom.uuid
    )
    
    conversation = @assistant.conversation_for_run(run_id)
    assert_includes conversation, message1
    assert_includes conversation, message2
    assert_not_includes conversation, other_message
  end

  test "clear_history! removes all messages" do
    @assistant.assistant_messages.create!(
      role: 'user',
      content: 'Test',
      run_id: SecureRandom.uuid
    )
    
    assert_difference '@assistant.assistant_messages.count', -1 do
      @assistant.clear_history!
    end
  end
end