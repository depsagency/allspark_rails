import React, { useState } from 'react';
import { getBezierPath, EdgeLabelRenderer } from '@xyflow/react';

const BaseEdge = ({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  style = {},
  markerEnd,
  data,
  selected,
  strokeColor = 'stroke-primary',
  strokeStyle = '',
  onDelete,
}) => {
  const [isHovered, setIsHovered] = useState(false);
  
  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition,
  });

  const handleDelete = (e) => {
    e.stopPropagation();
    if (data?.onDelete) {
      data.onDelete();
    }
  };

  return (
    <>
      {/* Invisible wider path for easier clicking */}
      <path
        d={edgePath}
        fill="none"
        strokeWidth={20}
        stroke="transparent"
        style={{ cursor: 'pointer' }}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      />
      
      {/* Visible edge path */}
      <path
        id={id}
        style={style}
        className={`${strokeColor} ${strokeStyle} fill-none hover:${strokeColor}-focus transition-colors`}
        d={edgePath}
        markerEnd={markerEnd}
        strokeWidth={selected ? 3 : 2}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      />
      
      {/* Edge label */}
      {data?.label && (
        <EdgeLabelRenderer>
          <div
            style={{
              position: 'absolute',
              transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
              pointerEvents: 'all',
            }}
            className="bg-base-100 px-2 py-1 text-xs rounded border border-primary"
          >
            {data.label}
          </div>
        </EdgeLabelRenderer>
      )}
      
      {/* Delete button */}
      {(isHovered || selected) && !data?.readOnly && (
        <EdgeLabelRenderer>
          <div
            style={{
              position: 'absolute',
              transform: `translate(-50%, -50%) translate(${labelX}px,${labelY - 20}px)`,
              pointerEvents: 'all',
            }}
          >
            <button
              className="btn btn-xs btn-error btn-circle"
              onClick={handleDelete}
              title="Delete connection"
            >
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                className="h-3 w-3" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
              >
                <path 
                  strokeLinecap="round" 
                  strokeLinejoin="round" 
                  strokeWidth={2} 
                  d="M6 18L18 6M6 6l12 12" 
                />
              </svg>
            </button>
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
};

export default BaseEdge;