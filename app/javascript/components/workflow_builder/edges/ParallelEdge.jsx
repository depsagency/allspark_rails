import React from 'react';
import { getStraightPath } from '@xyflow/react';
import BaseEdge from './BaseEdge';

const ParallelEdge = (props) => {
  const { sourceX, sourceY, targetX, targetY, id, style, markerEnd } = props;
  
  // Create a parallel line effect
  const offset = 3;
  const [edgePath2] = getStraightPath({
    sourceX: sourceX + offset,
    sourceY: sourceY + offset,
    targetX: targetX + offset,
    targetY: targetY + offset,
  });
  
  return (
    <>
      <BaseEdge
        {...props}
        strokeColor="stroke-secondary"
        strokeStyle="stroke-2"
      />
      {/* Additional parallel line for visual effect */}
      <path
        id={`${id}-parallel`}
        style={style}
        className="stroke-secondary stroke-2 fill-none opacity-50"
        d={edgePath2}
      />
    </>
  );
};

export default ParallelEdge;