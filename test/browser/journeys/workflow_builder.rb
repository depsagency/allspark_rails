require_relative '../base_journey'

class WorkflowBuilderJourney < BaseJourney
  include JourneyHelper

  journey :workflow_builder do
    setup_session

    begin
      step "Login as admin" do
        login_as("admin@example.com", "password123")
        expect_no_errors
      end

      step "Navigate to workflows" do
        visit "/workflows"
        wait_for_turbo
        expect_page_to_have("Workflows")
        expect_no_errors
      end

      step "Create a new workflow" do
        click_link "New Workflow"
        wait_for_turbo
        fill_in "Name", with: "Test Edge Deletion Workflow"
        fill_in "Description", with: "Testing edge deletion functionality"
        click_button "Create Workflow"
        expect_success("Workflow created")
      end

      step "Add nodes to workflow" do
        # Wait for workflow builder to load
        wait_for_selector(".react-flow")
        
        # Add start node
        drag_node_type("start", position: { x: 100, y: 100 })
        
        # Add task node
        drag_node_type("task", position: { x: 300, y: 100 })
        
        # Add decision node
        drag_node_type("decision", position: { x: 500, y: 100 })
        
        # Add end node
        drag_node_type("end", position: { x: 700, y: 100 })
        
        expect_no_errors
      end

      step "Connect nodes with edges" do
        # Connect start to task
        connect_nodes(from: "start", to: "task")
        
        # Connect task to decision
        connect_nodes(from: "task", to: "decision")
        
        # Connect decision to end
        connect_nodes(from: "decision", to: "end")
        
        # Verify edges exist
        expect_selector(".react-flow__edge", count: 3)
        expect_no_errors
      end

      step "Test edge selection" do
        # Click on the first edge
        find(".react-flow__edge", match: :first).click
        
        # Verify edge is selected (should have red stroke)
        expect_selector(".react-flow__edge[style*='stroke: rgb(255, 107, 107)']")
        
        # Verify delete button appears
        expect_selector(".btn-error.btn-circle")
        
        expect_no_errors
      end

      step "Test edge deletion via delete button" do
        # Click the delete button
        find(".btn-error.btn-circle").click
        
        # Verify edge count decreased
        expect_selector(".react-flow__edge", count: 2)
        
        expect_no_errors
      end

      step "Test edge deletion via keyboard" do
        # Select another edge
        find(".react-flow__edge", match: :first).click
        
        # Press Delete key
        page.send_keys(:delete)
        
        # Verify edge count decreased
        expect_selector(".react-flow__edge", count: 1)
        
        expect_no_errors
      end

      step "Save workflow and verify persistence" do
        click_button "Save Workflow"
        expect_success("Workflow saved")
        
        # Reload page
        visit current_path
        wait_for_turbo
        
        # Verify only 1 edge remains
        wait_for_selector(".react-flow__edge", count: 1)
        
        expect_no_errors
      end

      step "Test read-only mode" do
        # Navigate to view mode (assuming there's a view/edit toggle)
        visit "#{current_path}?mode=view"
        wait_for_turbo
        
        # Try to click on edge
        find(".react-flow__edge").click
        
        # Verify no delete button appears
        expect_no_selector(".btn-error.btn-circle")
        
        expect_no_errors
      end

    ensure
      teardown_session
    end
  end

  private

  def drag_node_type(node_type, position:)
    # Find the node in the sidebar
    node_element = find("[data-node-type='#{node_type}']")
    
    # Find the canvas
    canvas = find(".react-flow__renderer")
    
    # Perform drag and drop
    node_element.drag_to(canvas, 
      html5: true,
      drop_modifiers: [:move],
      drop_offset: position
    )
    
    sleep 0.5 # Allow time for node to be added
  end

  def connect_nodes(from:, to:)
    # Find source node handle
    source_handle = find(".react-flow__node[data-type='#{from}'] .react-flow__handle-source")
    
    # Find target node handle
    target_handle = find(".react-flow__node[data-type='#{to}'] .react-flow__handle-target")
    
    # Drag from source to target
    source_handle.drag_to(target_handle, html5: true)
    
    sleep 0.5 # Allow time for edge to be created
  end
end