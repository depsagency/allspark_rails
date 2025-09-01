import React from 'react';
import BaseNode from './BaseNode';

const TaskNode = ({ data, selected }) => {
  const progress = data.progress || 0;
  const isRunning = data.status === 'running';
  
  return (
    <BaseNode className={`border-info ${selected ? 'ring-2 ring-info' : ''}`}>
      <div className="space-y-2">
        <div>
          <div className="font-semibold text-sm">{data.title || 'Unnamed Task'}</div>
          {data.description && (
            <div className="text-xs opacity-70 mt-1 line-clamp-2">{data.description}</div>
          )}
        </div>
        
        {data.assignee && (
          <div className="flex items-center gap-2 text-xs">
            <div className="badge badge-sm badge-primary">{data.assignee.name}</div>
          </div>
        )}
        
        {data.estimatedTime && (
          <div className="text-xs opacity-60">⏱ {data.estimatedTime}</div>
        )}
        
        {isRunning && (
          <div className="space-y-1">
            <div className="flex justify-between text-xs">
              <span>Progress</span>
              <span>{progress}%</span>
            </div>
            <progress 
              className="progress progress-info w-full h-2" 
              value={progress} 
              max="100"
            />
          </div>
        )}
      </div>
    </BaseNode>
  );
};

export default TaskNode;