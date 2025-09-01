// Manual test script for workflow edge deletion
// This can be run in the browser console on the workflow edit page

const testWorkflowEdgeDeletion = () => {
  console.log('=== Testing Workflow Edge Deletion ===');
  
  // Test 1: Check if ReactFlow is loaded
  const reactFlowElement = document.querySelector('.react-flow');
  if (!reactFlowElement) {
    console.error('❌ ReactFlow not found on page');
    return;
  }
  console.log('✅ ReactFlow found');
  
  // Test 2: Check for edges
  const edges = document.querySelectorAll('.react-flow__edge');
  console.log(`✅ Found ${edges.length} edges`);
  
  if (edges.length === 0) {
    console.warn('⚠️  No edges found to test deletion');
    return;
  }
  
  // Test 3: Click on first edge to select
  console.log('📍 Testing edge selection...');
  const firstEdge = edges[0];
  const clickEvent = new MouseEvent('click', {
    bubbles: true,
    cancelable: true,
    view: window
  });
  firstEdge.dispatchEvent(clickEvent);
  
  setTimeout(() => {
    // Check if edge is selected (should have red stroke)
    const selectedEdge = document.querySelector('.react-flow__edge[style*="stroke: rgb(255, 107, 107)"]');
    if (selectedEdge) {
      console.log('✅ Edge selection working - edge turns red when clicked');
    } else {
      console.error('❌ Edge selection not working - no red stroke found');
    }
    
    // Test 4: Check for delete button
    const deleteButton = document.querySelector('.btn-error.btn-circle');
    if (deleteButton) {
      console.log('✅ Delete button appears when edge is selected');
      
      // Test 5: Check hover state
      console.log('📍 Testing hover delete button...');
      const hoverEvent = new MouseEvent('mouseenter', {
        bubbles: true,
        cancelable: true,
        view: window
      });
      edges[1]?.dispatchEvent(hoverEvent);
      
      setTimeout(() => {
        const hoverDeleteButtons = document.querySelectorAll('.btn-error.btn-circle');
        if (hoverDeleteButtons.length > 1) {
          console.log('✅ Delete button appears on hover');
        } else {
          console.warn('⚠️  Hover delete button may not be working');
        }
        
        // Test 6: Keyboard deletion
        console.log('📍 Testing keyboard deletion...');
        console.log('ℹ️  Press Delete or Backspace with an edge selected to test keyboard deletion');
        
        // Summary
        console.log('\n=== Test Summary ===');
        console.log('✅ Edge deletion UI components are present');
        console.log('ℹ️  Manual actions to verify:');
        console.log('   1. Click an edge and press Delete key');
        console.log('   2. Click the red X button to delete');
        console.log('   3. Verify edges are removed from the graph');
        console.log('   4. Save workflow and reload to verify persistence');
        
      }, 500);
    } else {
      console.error('❌ Delete button not found when edge is selected');
    }
  }, 500);
};

// Run the test
testWorkflowEdgeDeletion();

// Export for reuse
window.testWorkflowEdgeDeletion = testWorkflowEdgeDeletion;