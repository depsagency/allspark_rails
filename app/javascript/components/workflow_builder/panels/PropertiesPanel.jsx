import React, { useState, useEffect } from 'react';

const PropertiesPanel = ({ selectedNode, teamMembers = [], onUpdateNode, readOnly }) => {
  const [formData, setFormData] = useState({});

  useEffect(() => {
    if (selectedNode) {
      setFormData(selectedNode.data || {});
    }
  }, [selectedNode]);

  const handleChange = (field, value) => {
    const newData = { ...formData, [field]: value };
    setFormData(newData);
    if (onUpdateNode && selectedNode) {
      onUpdateNode(selectedNode.id, newData);
    }
  };

  if (!selectedNode) {
    return (
      <div className="w-80 bg-base-200 p-4 border-l border-base-300">
        <h3 className="text-lg font-bold mb-4">Properties</h3>
        <div className="text-center py-8 text-base-content/60">
          <p>Select a node to configure</p>
        </div>
      </div>
    );
  }

  const renderTaskForm = () => (
    <div className="space-y-4">
      <div className="form-control">
        <label className="label">
          <span className="label-text">Title</span>
        </label>
        <input
          type="text"
          className="input input-bordered"
          value={formData.title || ''}
          onChange={(e) => handleChange('title', e.target.value)}
          disabled={readOnly}
          placeholder="Enter task title"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Instructions</span>
        </label>
        <textarea
          className="textarea textarea-bordered h-24"
          value={formData.instructions || ''}
          onChange={(e) => handleChange('instructions', e.target.value)}
          disabled={readOnly}
          placeholder="Enter detailed instructions for this task"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Assign to</span>
        </label>
        <select
          className="select select-bordered"
          value={formData.assignee?.id || ''}
          onChange={(e) => {
            const assistant = teamMembers.find(m => m.id === e.target.value);
            handleChange('assignee', assistant);
          }}
          disabled={readOnly}
        >
          <option value="">Unassigned</option>
          {teamMembers.map((member) => (
            <option key={member.id} value={member.id}>
              {member.name}
            </option>
          ))}
        </select>
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Estimated Time</span>
        </label>
        <input
          type="text"
          className="input input-bordered"
          value={formData.estimatedTime || ''}
          onChange={(e) => handleChange('estimatedTime', e.target.value)}
          disabled={readOnly}
          placeholder="e.g., 2 hours, 30 minutes"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Task Timeout</span>
          <span className="label-text-alt">Maximum execution time</span>
        </label>
        <select
          className="select select-bordered"
          value={formData.timeout || ''}
          onChange={(e) => handleChange('timeout', e.target.value)}
          disabled={readOnly}
        >
          <option value="">Auto-detect</option>
          <option value="60">1 minute</option>
          <option value="180">3 minutes</option>
          <option value="300">5 minutes</option>
          <option value="600">10 minutes</option>
          <option value="900">15 minutes</option>
          <option value="1800">30 minutes</option>
          <option value="3600">1 hour</option>
        </select>
        <label className="label">
          <span className="label-text-alt">Task will fail if it runs longer than this</span>
        </label>
      </div>
    </div>
  );

  const renderDecisionForm = () => (
    <div className="space-y-4">
      <div className="form-control">
        <label className="label">
          <span className="label-text">Decision Title</span>
        </label>
        <input
          type="text"
          className="input input-bordered"
          value={formData.title || ''}
          onChange={(e) => handleChange('title', e.target.value)}
          disabled={readOnly}
          placeholder="Enter decision title"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Condition</span>
        </label>
        <textarea
          className="textarea textarea-bordered"
          value={formData.condition || ''}
          onChange={(e) => handleChange('condition', e.target.value)}
          disabled={readOnly}
          placeholder="Describe the decision condition"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Branches</span>
        </label>
        <div className="space-y-2">
          <input
            type="text"
            className="input input-bordered input-sm"
            placeholder="True branch label"
            disabled={readOnly}
          />
          <input
            type="text"
            className="input input-bordered input-sm"
            placeholder="False branch label"
            disabled={readOnly}
          />
        </div>
      </div>
    </div>
  );

  const renderAssistantForm = () => (
    <div className="space-y-4">
      <div className="form-control">
        <label className="label">
          <span className="label-text">Assistant</span>
        </label>
        <select
          className="select select-bordered"
          value={formData.assignee?.id || ''}
          onChange={(e) => {
            const assistant = teamMembers.find(m => m.id === e.target.value);
            handleChange('assignee', assistant);
          }}
          disabled={readOnly}
        >
          <option value="">Select assistant</option>
          {teamMembers.map((member) => (
            <option key={member.id} value={member.id}>
              {member.name}
            </option>
          ))}
        </select>
      </div>

      {formData.assignee && (
        <div className="alert alert-info">
          <div>
            <h4 className="font-semibold">{formData.assignee.name}</h4>
            {formData.assignee.role && (
              <p className="text-sm">{formData.assignee.role}</p>
            )}
            {formData.assignee.skills && (
              <div className="flex flex-wrap gap-1 mt-1">
                {formData.assignee.skills.map((skill, index) => (
                  <span key={index} className="badge badge-sm">
                    {skill}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      <div className="form-control">
        <label className="label">
          <span className="label-text">Task</span>
        </label>
        <textarea
          className="textarea textarea-bordered"
          value={formData.task?.title || ''}
          onChange={(e) => handleChange('task', { ...formData.task, title: e.target.value })}
          disabled={readOnly}
          placeholder="What should this assistant do?"
        />
      </div>

      <div className="form-control">
        <label className="label">
          <span className="label-text">Task Timeout</span>
          <span className="label-text-alt">Maximum execution time</span>
        </label>
        <select
          className="select select-bordered"
          value={formData.timeout || ''}
          onChange={(e) => handleChange('timeout', e.target.value)}
          disabled={readOnly}
        >
          <option value="">Auto-detect</option>
          <option value="60">1 minute</option>
          <option value="180">3 minutes</option>
          <option value="300">5 minutes</option>
          <option value="600">10 minutes</option>
          <option value="900">15 minutes</option>
          <option value="1800">30 minutes</option>
          <option value="3600">1 hour</option>
        </select>
        <label className="label">
          <span className="label-text-alt">Task will fail if it runs longer than this</span>
        </label>
      </div>
    </div>
  );

  const renderFormByType = () => {
    switch (selectedNode.type) {
      case 'task':
        return renderTaskForm();
      case 'decision':
        return renderDecisionForm();
      case 'assistant':
        return renderAssistantForm();
      case 'start':
      case 'end':
        return (
          <div className="text-center py-8 text-base-content/60">
            <p>No properties to configure</p>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="w-80 bg-base-200 p-4 border-l border-base-300 overflow-y-auto">
      <h3 className="text-lg font-bold mb-4">
        {selectedNode.type.charAt(0).toUpperCase() + selectedNode.type.slice(1)} Properties
      </h3>
      
      <div className="mb-4">
        <div className="badge badge-primary">{selectedNode.type}</div>
        <div className="text-xs opacity-70 mt-1">ID: {selectedNode.id}</div>
      </div>

      {renderFormByType()}

      {selectedNode.type !== 'start' && selectedNode.type !== 'end' && (
        <div className="mt-6 pt-4 border-t border-base-300">
          <h4 className="font-semibold mb-2">Dependencies</h4>
          <p className="text-sm text-base-content/70">
            Configure in the workflow by connecting nodes
          </p>
        </div>
      )}
    </div>
  );
};

export default PropertiesPanel;