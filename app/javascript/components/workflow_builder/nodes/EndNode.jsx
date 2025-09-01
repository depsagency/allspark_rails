import React from 'react';
import { Handle } from '@xyflow/react';

const EndNode = ({ data }) => {
  return (
    <div className="bg-error text-error-content rounded-full w-20 h-20 flex items-center justify-center shadow-lg border-4 border-error-content/20">
      <Handle
        type="target"
        position="top"
        className="w-3 h-3 bg-error-content border-2 border-error"
      />
      
      <div className="text-center font-bold">End</div>
    </div>
  );
};

export default EndNode;