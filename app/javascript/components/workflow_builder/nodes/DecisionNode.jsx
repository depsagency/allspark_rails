import React from 'react';
import { Handle } from '@xyflow/react';

const DecisionNode = ({ data, selected }) => {
  const branches = data.branches || [];
  
  return (
    <div className={`relative ${selected ? 'ring-2 ring-warning' : ''}`}>
      <Handle
        type="target"
        position="top"
        className="w-3 h-3 bg-warning border-2 border-base-100"
      />
      
      <div className="bg-warning text-warning-content border-4 border-warning-content/20 shadow-lg"
           style={{
             width: '120px',
             height: '120px',
             transform: 'rotate(45deg)',
             display: 'flex',
             alignItems: 'center',
             justifyContent: 'center'
           }}>
        <div style={{ transform: 'rotate(-45deg)' }} className="text-center p-2">
          <div className="font-bold text-sm">{data.title || 'Decision'}</div>
          {data.condition && (
            <div className="text-xs opacity-80 mt-1">{data.condition}</div>
          )}
        </div>
      </div>
      
      {/* Multiple output handles for branches */}
      <Handle
        type="source"
        position="bottom"
        id="default"
        className="w-3 h-3 bg-warning border-2 border-base-100"
        style={{ left: '50%' }}
      />
      
      {branches.length > 0 && (
        <>
          <Handle
            type="source"
            position="right"
            id="branch-1"
            className="w-3 h-3 bg-warning border-2 border-base-100"
            style={{ top: '50%' }}
          />
          <Handle
            type="source"
            position="left"
            id="branch-2"
            className="w-3 h-3 bg-warning border-2 border-base-100"
            style={{ top: '50%' }}
          />
        </>
      )}
    </div>
  );
};

export default DecisionNode;