import React from 'react';
import BaseNode from './BaseNode';

const AssistantNode = ({ data, selected }) => {
  const statusColors = {
    idle: 'bg-base-300',
    busy: 'bg-warning',
    completed: 'bg-success',
    failed: 'bg-error'
  };
  
  const status = data.status || 'idle';
  const statusColor = statusColors[status] || statusColors.idle;
  
  return (
    <BaseNode className={`border-primary ${selected ? 'ring-2 ring-primary' : ''}`}>
      <div className="flex items-center gap-2 mb-2">
        <div className={`w-10 h-10 rounded-full ${statusColor} flex items-center justify-center text-white font-bold`}>
          {data.assignee?.name?.charAt(0) || 'A'}
        </div>
        <div className="flex-1">
          <div className="font-semibold text-sm">{data.assignee?.name || 'Unassigned'}</div>
          <div className="text-xs opacity-70">Assistant</div>
        </div>
      </div>
      
      {data.task && (
        <div className="mt-2 pt-2 border-t border-base-300">
          <div className="text-xs font-medium">{data.task.title}</div>
          {data.estimatedTime && (
            <div className="text-xs opacity-60 mt-1">⏱ {data.estimatedTime}</div>
          )}
        </div>
      )}
      
      {status === 'busy' && (
        <div className="mt-2">
          <div className="progress progress-primary h-1"></div>
        </div>
      )}
    </BaseNode>
  );
};

export default AssistantNode;