import React from 'react';
import { Handle } from '@xyflow/react';

const BaseNode = ({ children, showInput = true, showOutput = true, className = '', ...props }) => {
  return (
    <div className={`bg-base-100 border-2 rounded-lg shadow-lg p-4 min-w-[150px] ${className}`}>
      {showInput && (
        <Handle
          type="target"
          position="top"
          className="w-3 h-3 bg-primary border-2 border-base-100"
        />
      )}
      
      {children}
      
      {showOutput && (
        <Handle
          type="source"
          position="bottom"
          className="w-3 h-3 bg-primary border-2 border-base-100"
        />
      )}
    </div>
  );
};

export default BaseNode;