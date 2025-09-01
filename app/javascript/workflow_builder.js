import React from 'react';
import { createRoot } from 'react-dom/client';
import WorkflowBuilder from './components/workflow_builder/WorkflowBuilder';

// Function to mount the workflow builder
window.mountWorkflowBuilder = (elementId, props = {}) => {
  const element = document.getElementById(elementId);
  if (!element) {
    console.error(`Element with id ${elementId} not found`);
    return;
  }

  // Get data attributes from the element
  const workflow = element.dataset.workflow ? JSON.parse(element.dataset.workflow) : null;
  const teamMembers = element.dataset.teamMembers ? JSON.parse(element.dataset.teamMembers) : [];
  const readOnly = element.dataset.readOnly === 'true';
  const workflowId = element.dataset.workflowId;
  const teamId = element.dataset.teamId;

  const handleSave = async (workflowData) => {
    try {
      const url = workflowId 
        ? `/agents/teams/${teamId}/workflows/${workflowId}`
        : `/agents/teams/${teamId}/workflows`;
      
      const method = workflowId ? 'PATCH' : 'POST';
      
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          workflow: {
            flow_definition: workflowData,
            name: workflowData.name || 'Untitled Workflow',
          },
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to save workflow');
      }

      const result = await response.json();
      
      // Show success message
      const event = new CustomEvent('workflow:saved', { detail: result });
      window.dispatchEvent(event);
      
      // If it's a new workflow, update the URL
      if (!workflowId && result.id) {
        window.history.pushState({}, '', `/agents/teams/${teamId}/workflows/${result.id}/edit`);
      }
      
      return result;
    } catch (error) {
      console.error('Error saving workflow:', error);
      const event = new CustomEvent('workflow:error', { detail: { error: error.message } });
      window.dispatchEvent(event);
      throw error;
    }
  };

  const handleExecute = async (workflowData) => {
    try {
      if (!workflowId) {
        alert('Please save the workflow before executing');
        return;
      }

      const response = await fetch(`/agents/teams/${teamId}/workflows/${workflowId}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        },
        body: JSON.stringify({}),
      });

      if (!response.ok) {
        throw new Error('Failed to execute workflow');
      }

      const result = await response.json();
      
      // Redirect to execution view
      window.location.href = `/agents/teams/${teamId}/workflows/${workflowId}/executions/${result.id}`;
      
      return result;
    } catch (error) {
      console.error('Error executing workflow:', error);
      const event = new CustomEvent('workflow:error', { detail: { error: error.message } });
      window.dispatchEvent(event);
      throw error;
    }
  };

  // Render the workflow builder
  const root = createRoot(element);
  root.render(
    <WorkflowBuilder
      initialWorkflow={workflow}
      teamMembers={teamMembers}
      onSave={handleSave}
      onExecute={handleExecute}
      readOnly={readOnly}
      {...props}
    />
  );

  // Return cleanup function
  return () => {
    root.unmount();
  };
};

// Auto-mount if there's a workflow-builder element on page load
document.addEventListener('DOMContentLoaded', () => {
  const builderElement = document.getElementById('workflow-builder');
  if (builderElement) {
    window.mountWorkflowBuilder('workflow-builder');
  }
});

// Export for use in Stimulus controllers
export { WorkflowBuilder };