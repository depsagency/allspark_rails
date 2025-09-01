import React from 'react';
import BaseEdge from './BaseEdge';

const ConditionalEdge = (props) => {
  return (
    <BaseEdge
      {...props}
      strokeColor="stroke-warning"
      strokeStyle="stroke-2"
      style={{ strokeDasharray: '5,5' }}
    />
  );
};

export default ConditionalEdge;