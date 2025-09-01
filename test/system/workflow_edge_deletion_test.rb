require "application_system_test_case"

class WorkflowEdgeDeletionTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @team = agent_teams(:one)
    @workflow = workflows(:one)
    
    # Ensure workflow has proper edge structure for testing
    @workflow.update!(
      flow_definition: {
        nodes: [
          { id: 'start_1', type: 'start', position: { x: 100, y: 100 }, data: { title: 'Start' } },
          { id: 'task_1', type: 'task', position: { x: 300, y: 100 }, data: { title: 'Task 1' } },
          { id: 'task_2', type: 'task', position: { x: 500, y: 100 }, data: { title: 'Task 2' } },
          { id: 'end_1', type: 'end', position: { x: 700, y: 100 }, data: { title: 'End' } }
        ],
        edges: [
          { id: 'edge_1', source: 'start_1', target: 'task_1', type: 'sequential' },
          { id: 'edge_2', source: 'task_1', target: 'task_2', type: 'conditional' },
          { id: 'edge_3', source: 'task_2', target: 'end_1', type: 'parallel' }
        ]
      }
    )
    
    sign_in @user
  end

  test "edge deletion via click and delete button" do
    visit edit_agents_team_workflow_path(@team, @workflow)
    
    # Wait for React workflow builder to load
    assert_selector ".react-flow", wait: 10
    assert_selector ".react-flow__edge", count: 3
    
    # Click on first edge to select it
    first(".react-flow__edge").click
    
    # Verify edge is selected (red stroke)
    assert_selector ".react-flow__edge[style*='stroke: rgb(255, 107, 107)']"
    
    # Verify delete button appears
    assert_selector ".btn-error.btn-circle"
    
    # Click delete button
    find(".btn-error.btn-circle").click
    
    # Verify edge count decreased
    assert_selector ".react-flow__edge", count: 2
  end

  test "edge deletion via keyboard" do
    visit edit_agents_team_workflow_path(@team, @workflow)
    
    # Wait for React workflow builder to load
    assert_selector ".react-flow", wait: 10
    assert_selector ".react-flow__edge", count: 3
    
    # Click on first edge to select it
    first(".react-flow__edge").click
    
    # Press Delete key
    page.send_keys(:delete)
    
    # Verify edge count decreased
    assert_selector ".react-flow__edge", count: 2
  end

  test "edge deletion on hover" do
    visit edit_agents_team_workflow_path(@team, @workflow)
    
    # Wait for React workflow builder to load
    assert_selector ".react-flow", wait: 10
    
    # Hover over edge
    first(".react-flow__edge").hover
    
    # Verify delete button appears
    assert_selector ".btn-error.btn-circle"
  end

  test "edge deletion is disabled in read-only mode" do
    # Visit in read-only mode
    visit agents_team_workflow_path(@team, @workflow)
    
    # Wait for React workflow builder to load
    assert_selector ".react-flow", wait: 10
    
    # Try to click on edge
    first(".react-flow__edge").click
    
    # Verify no delete button appears
    assert_no_selector ".btn-error.btn-circle", wait: 2
  end

  test "edge deletion persists after save" do
    visit edit_agents_team_workflow_path(@team, @workflow)
    
    # Wait for React workflow builder to load
    assert_selector ".react-flow", wait: 10
    assert_selector ".react-flow__edge", count: 3
    
    # Delete an edge
    first(".react-flow__edge").click
    find(".btn-error.btn-circle").click
    
    # Verify edge deleted
    assert_selector ".react-flow__edge", count: 2
    
    # Save workflow
    click_button "Save Workflow"
    
    # Wait for save confirmation
    assert_text "Workflow saved successfully!"
    
    # Reload page
    visit edit_agents_team_workflow_path(@team, @workflow)
    
    # Verify edge count is still 2
    assert_selector ".react-flow", wait: 10
    assert_selector ".react-flow__edge", count: 2
  end
end