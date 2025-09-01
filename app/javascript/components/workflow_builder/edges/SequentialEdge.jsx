import React from 'react';
import BaseEdge from './BaseEdge';

const SequentialEdge = (props) => {
  return (
    <BaseEdge
      {...props}
      strokeColor="stroke-primary"
      strokeStyle="stroke-2"
    />
  );
};

export default SequentialEdge;