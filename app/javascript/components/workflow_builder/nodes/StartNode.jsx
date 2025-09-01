import React from 'react';
import { Handle } from '@xyflow/react';

const StartNode = ({ data }) => {
  return (
    <div className="bg-success text-success-content rounded-full w-20 h-20 flex items-center justify-center shadow-lg border-4 border-success-content/20">
      <div className="text-center font-bold">Start</div>
      
      <Handle
        type="source"
        position="bottom"
        className="w-3 h-3 bg-success-content border-2 border-success"
      />
    </div>
  );
};

export default StartNode;