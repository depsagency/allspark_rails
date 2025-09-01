import React, { useState } from 'react';

const WorkflowToolbar = ({ onSave, onExecute, readOnly }) => {
  const [isSaving, setIsSaving] = useState(false);
  
  const nodeTypes = [
    { type: 'start', label: 'Start', icon: '▶️', color: 'btn-success' },
    { type: 'task', label: 'Task', icon: '📋', color: 'btn-info' },
    { type: 'decision', label: 'Decision', icon: '🔀', color: 'btn-warning' },
    { type: 'end', label: 'End', icon: '🏁', color: 'btn-error' },
  ];

  const handleDragStart = (event, nodeType) => {
    event.dataTransfer.setData('nodeType', nodeType);
    event.dataTransfer.effectAllowed = 'move';
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await onSave();
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="navbar bg-base-200 shadow-lg px-4">
      <div className="flex-1">
        <div className="flex gap-2">
          {!readOnly && nodeTypes.map((node) => (
            <button
              key={node.type}
              className={`btn btn-sm ${node.color}`}
              draggable
              onDragStart={(e) => handleDragStart(e, node.type)}
              title={`Drag to add ${node.label} node`}
            >
              <span className="text-lg mr-1">{node.icon}</span>
              {node.label}
            </button>
          ))}
        </div>
      </div>
      
      <div className="flex-none gap-2">
        {!readOnly && (
          <>
            <div className="divider divider-horizontal"></div>
            <button className="btn btn-sm btn-ghost" title="Undo">
              ↩️ Undo
            </button>
            <button className="btn btn-sm btn-ghost" title="Redo">
              ↪️ Redo
            </button>
            <button className="btn btn-sm btn-ghost" title="Auto Layout">
              📐 Auto Layout
            </button>
          </>
        )}
        
        <div className="divider divider-horizontal"></div>
        
        {!readOnly && (
          <button 
            className={`btn btn-sm btn-primary ${isSaving ? 'loading' : ''}`}
            onClick={handleSave}
            disabled={isSaving}
          >
            💾 Save
          </button>
        )}
        
        <button 
          className="btn btn-sm btn-secondary"
          onClick={onExecute}
        >
          ▶️ Run Workflow
        </button>
        
        <div className="dropdown dropdown-end">
          <label tabIndex={0} className="btn btn-sm btn-ghost">
            📤 Export
          </label>
          <ul tabIndex={0} className="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52">
            <li><a>Export as Mermaid</a></li>
            <li><a>Export as PNG</a></li>
            <li><a>Export as JSON</a></li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default WorkflowToolbar;