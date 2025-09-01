import React, { useState, useCallback, useRef } from 'react';
import {
  ReactFlow,
  Controls,
  Background,
  MiniMap,
  addEdge,
  applyNodeChanges,
  applyEdgeChanges,
  MarkerType,
  ReactFlowProvider,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

// Import custom nodes
import StartNode from './nodes/StartNode';
import EndNode from './nodes/EndNode';
import AssistantNode from './nodes/AssistantNode';
import TaskNode from './nodes/TaskNode';
import DecisionNode from './nodes/DecisionNode';

// Import custom edges
import SequentialEdge from './edges/SequentialEdge';
import ConditionalEdge from './edges/ConditionalEdge';
import ParallelEdge from './edges/ParallelEdge';

// Import panels
import WorkflowToolbar from './controls/WorkflowToolbar';
import TeamMembersSidebar from './panels/TeamMembersSidebar';
import PropertiesPanel from './panels/PropertiesPanel';

const nodeTypes = {
  start: StartNode,
  end: EndNode,
  assistant: AssistantNode,
  task: TaskNode,
  decision: DecisionNode,
};

const edgeTypes = {
  sequential: SequentialEdge,
  conditional: ConditionalEdge,
  parallel: ParallelEdge,
};

const defaultEdgeOptions = {
  animated: true,
  style: { strokeWidth: 2 },
  markerEnd: {
    type: MarkerType.ArrowClosed,
    width: 20,
    height: 20,
  },
};

const WorkflowBuilder = ({ 
  initialWorkflow, 
  teamMembers = [], 
  onSave,
  onExecute,
  readOnly = false 
}) => {
  const reactFlowWrapper = useRef(null);
  const [nodes, setNodes] = useState(initialWorkflow?.nodes || []);
  const [edges, setEdges] = useState(initialWorkflow?.edges || []);
  const [selectedNode, setSelectedNode] = useState(null);
  const [selectedEdge, setSelectedEdge] = useState(null);
  const [reactFlowInstance, setReactFlowInstance] = useState(null);

  const onNodesChange = useCallback(
    (changes) => setNodes((nds) => applyNodeChanges(changes, nds)),
    []
  );

  const onEdgesChange = useCallback(
    (changes) => setEdges((eds) => applyEdgeChanges(changes, eds)),
    []
  );

  const onConnect = useCallback(
    (params) => {
      const newEdge = {
        ...params,
        type: 'sequential',
        animated: true,
      };
      setEdges((eds) => addEdge(newEdge, eds));
    },
    []
  );

  const onNodeClick = useCallback((event, node) => {
    setSelectedNode(node);
    setSelectedEdge(null); // Clear edge selection when node is clicked
  }, []);

  const onEdgeClick = useCallback((event, edge) => {
    if (!readOnly) {
      setSelectedEdge(edge);
      setSelectedNode(null); // Clear node selection when edge is clicked
    }
  }, [readOnly]);

  const deleteSelectedEdge = useCallback(() => {
    if (selectedEdge && !readOnly) {
      setEdges((eds) => eds.filter((edge) => edge.id !== selectedEdge.id));
      setSelectedEdge(null);
    }
  }, [selectedEdge, readOnly]);

  // Keyboard handler for edge deletion
  const onKeyDown = useCallback((event) => {
    if ((event.key === 'Delete' || event.key === 'Backspace') && selectedEdge && !readOnly) {
      event.preventDefault();
      deleteSelectedEdge();
    }
  }, [selectedEdge, deleteSelectedEdge, readOnly]);

  // Add keyboard event listener
  React.useEffect(() => {
    if (reactFlowWrapper.current) {
      const wrapper = reactFlowWrapper.current;
      wrapper.addEventListener('keydown', onKeyDown);
      return () => wrapper.removeEventListener('keydown', onKeyDown);
    }
  }, [onKeyDown]);

  const onDragOver = useCallback((event) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback(
    (event) => {
      event.preventDefault();

      const type = event.dataTransfer.getData('nodeType');
      const assistantId = event.dataTransfer.getData('assistantId');

      if (!type || !reactFlowInstance) {
        return;
      }

      const position = reactFlowInstance.screenToFlowPosition({
        x: event.clientX,
        y: event.clientY,
      });

      const newNode = {
        id: `${type}_${Date.now()}`,
        type,
        position,
        data: {
          title: type === 'assistant' && assistantId 
            ? teamMembers.find(m => m.id === assistantId)?.name 
            : `New ${type}`,
          assignee: assistantId ? teamMembers.find(m => m.id === assistantId) : null,
        },
      };

      setNodes((nds) => nds.concat(newNode));
    },
    [reactFlowInstance, teamMembers]
  );

  const handleSave = useCallback(() => {
    if (onSave) {
      onSave({
        nodes,
        edges,
      });
    }
  }, [nodes, edges, onSave]);

  const handleExecute = useCallback(() => {
    if (onExecute) {
      onExecute({
        nodes,
        edges,
      });
    }
  }, [nodes, edges, onExecute]);

  const updateNodeData = useCallback((nodeId, newData) => {
    setNodes((nds) =>
      nds.map((node) => {
        if (node.id === nodeId) {
          return {
            ...node,
            data: {
              ...node.data,
              ...newData,
            },
          };
        }
        return node;
      })
    );
  }, []);

  return (
    <div className="h-screen flex flex-col">
      <WorkflowToolbar 
        onSave={handleSave}
        onExecute={handleExecute}
        readOnly={readOnly}
      />
      
      <div className="flex-1 flex">
        <TeamMembersSidebar 
          teamMembers={teamMembers} 
          readOnly={readOnly}
        />
        
        <div className="flex-1 relative" ref={reactFlowWrapper}>
          <ReactFlow
            nodes={nodes}
            edges={edges.map((edge) => ({
              ...edge,
              selected: selectedEdge?.id === edge.id,
              data: {
                ...edge.data,
                readOnly,
                onDelete: deleteSelectedEdge,
              },
              style: {
                ...edge.style,
                stroke: selectedEdge?.id === edge.id ? '#ff6b6b' : undefined,
                strokeWidth: selectedEdge?.id === edge.id ? 3 : 2,
              },
            }))}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={onNodeClick}
            onEdgeClick={onEdgeClick}
            onInit={setReactFlowInstance}
            onDrop={onDrop}
            onDragOver={onDragOver}
            nodeTypes={nodeTypes}
            edgeTypes={edgeTypes}
            defaultEdgeOptions={defaultEdgeOptions}
            deleteKeyCode={['Delete', 'Backspace']}
            fitView
            attributionPosition="bottom-left"
          >
            <Background variant="dots" gap={12} size={1} />
            <Controls />
            <MiniMap 
              nodeStrokeColor={(node) => {
                switch (node.type) {
                  case 'start': return '#10b981';
                  case 'end': return '#ef4444';
                  case 'decision': return '#f59e0b';
                  case 'assistant': return '#a855f7';
                  default: return '#3b82f6';
                }
              }}
              nodeColor={(node) => {
                switch (node.type) {
                  case 'start': return '#10b981';
                  case 'end': return '#ef4444';
                  case 'decision': return '#f59e0b';
                  case 'assistant': return '#a855f7';
                  default: return '#3b82f6';
                }
              }}
              pannable
              zoomable
            />
          </ReactFlow>
        </div>
        
        <PropertiesPanel 
          selectedNode={selectedNode}
          teamMembers={teamMembers}
          onUpdateNode={updateNodeData}
          readOnly={readOnly}
        />
      </div>
    </div>
  );
};

const WorkflowBuilderWrapper = (props) => {
  return (
    <ReactFlowProvider>
      <WorkflowBuilder {...props} />
    </ReactFlowProvider>
  );
};

export default WorkflowBuilderWrapper;