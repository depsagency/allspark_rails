import React, { useState } from 'react';

const TeamMembersSidebar = ({ teamMembers = [], readOnly }) => {
  const [searchTerm, setSearchTerm] = useState('');
  
  const filteredMembers = teamMembers.filter(member =>
    member.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleDragStart = (event, assistantId) => {
    event.dataTransfer.setData('nodeType', 'assistant');
    event.dataTransfer.setData('assistantId', assistantId);
    event.dataTransfer.effectAllowed = 'move';
  };

  return (
    <div className="w-64 bg-base-200 p-4 border-r border-base-300 overflow-y-auto">
      <h3 className="text-lg font-bold mb-4">Team Members</h3>
      
      {!readOnly && (
        <div className="form-control mb-4">
          <input
            type="text"
            placeholder="Search assistants..."
            className="input input-sm input-bordered"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      )}
      
      <div className="space-y-2">
        {filteredMembers.length === 0 ? (
          <div className="text-center py-8 text-base-content/60">
            <p>No team members found</p>
          </div>
        ) : (
          filteredMembers.map((member) => (
            <div
              key={member.id}
              className={`card bg-base-100 shadow-sm ${!readOnly ? 'cursor-move hover:shadow-md transition-shadow' : ''}`}
              draggable={!readOnly}
              onDragStart={(e) => handleDragStart(e, member.id)}
            >
              <div className="card-body p-3">
                <div className="flex items-center gap-2">
                  <div className="avatar placeholder">
                    <div className="bg-primary text-primary-content rounded-full w-8">
                      <span className="text-xs">{member.name.charAt(0)}</span>
                    </div>
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-sm truncate">{member.name}</h4>
                    {member.role && (
                      <p className="text-xs opacity-70">{member.role}</p>
                    )}
                  </div>
                  {member.available === false && (
                    <div className="badge badge-warning badge-sm">Busy</div>
                  )}
                </div>
                
                {member.skills && member.skills.length > 0 && (
                  <div className="flex flex-wrap gap-1 mt-2">
                    {member.skills.slice(0, 3).map((skill, index) => (
                      <span key={index} className="badge badge-ghost badge-xs">
                        {skill}
                      </span>
                    ))}
                    {member.skills.length > 3 && (
                      <span className="badge badge-ghost badge-xs">
                        +{member.skills.length - 3}
                      </span>
                    )}
                  </div>
                )}
              </div>
              
              {!readOnly && (
                <div className="text-center pb-2 px-3">
                  <p className="text-xs text-base-content/60">Drag to canvas</p>
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default TeamMembersSidebar;