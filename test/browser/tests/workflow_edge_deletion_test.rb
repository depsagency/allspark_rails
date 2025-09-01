require_relative '../test_helper'

class WorkflowEdgeDeletionTest < BrowserTest
  test "edge deletion functionality" do
    # Setup: Create a workflow with edges
    workflow = create_workflow_with_edges
    
    visit workflow_path(workflow)
    wait_for_react_flow
    
    # Test 1: Visual selection
    assert_edge_selection_works
    
    # Test 2: Delete button
    assert_delete_button_works
    
    # Test 3: Keyboard deletion
    assert_keyboard_deletion_works
    
    # Test 4: Read-only mode
    assert_readonly_mode_prevents_deletion
  end

  private

  def create_workflow_with_edges
    workflow = Workflow.create!(
      name: "Edge Deletion Test",
      description: "Testing edge deletion",
      definition: {
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
  end

  def wait_for_react_flow
    wait_for_selector(".react-flow__renderer")
    wait_for_selector(".react-flow__edge", count: 3)
  end

  def assert_edge_selection_works
    # Click on first edge
    edge = find(".react-flow__edge", match: :first)
    edge.click
    
    # Check for visual selection (red stroke)
    selected_edge = find(".react-flow__edge[style*='stroke: rgb(255, 107, 107)']")
    assert selected_edge.present?, "Edge should be visually selected with red stroke"
    
    # Check delete button appears
    delete_button = find(".btn-error.btn-circle", visible: true)
    assert delete_button.present?, "Delete button should appear when edge is selected"
  end

  def assert_delete_button_works
    initial_edge_count = all(".react-flow__edge").count
    
    # Click delete button
    find(".btn-error.btn-circle").click
    
    # Wait for edge to be removed
    wait_for_selector(".react-flow__edge", count: initial_edge_count - 1)
    
    new_edge_count = all(".react-flow__edge").count
    assert_equal initial_edge_count - 1, new_edge_count, "Edge should be deleted"
  end

  def assert_keyboard_deletion_works
    # Select an edge
    edge = find(".react-flow__edge", match: :first)
    edge.click
    
    initial_edge_count = all(".react-flow__edge").count
    
    # Press Delete key
    page.send_keys(:delete)
    
    # Wait for edge to be removed
    wait_for_selector(".react-flow__edge", count: initial_edge_count - 1)
    
    new_edge_count = all(".react-flow__edge").count
    assert_equal initial_edge_count - 1, new_edge_count, "Edge should be deleted via keyboard"
  end

  def assert_readonly_mode_prevents_deletion
    # Reload in read-only mode
    visit workflow_path(workflow, mode: 'view')
    wait_for_react_flow
    
    # Try to select edge
    edge = find(".react-flow__edge", match: :first)
    edge.click
    
    # Ensure no delete button appears
    assert_no_selector(".btn-error.btn-circle", wait: 2)
    
    # Try keyboard deletion
    initial_edge_count = all(".react-flow__edge").count
    page.send_keys(:delete)
    
    # Verify edge count hasn't changed
    sleep 0.5
    assert_equal initial_edge_count, all(".react-flow__edge").count, 
      "Edges should not be deletable in read-only mode"
  end
end