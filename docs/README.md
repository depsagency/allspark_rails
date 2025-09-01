# AllSpark Documentation

Welcome to the AllSpark documentation. This directory contains comprehensive documentation organized by purpose and audience.

## 📚 Documentation Structure

### [/reference](./reference)
**Current, maintained documentation for development and operations**

- **[/architecture](./reference/architecture)** - System design and technical architecture
- **[/deployment](./reference/deployment)** - Deployment guides and configurations
- **[/features](./reference/features)** - Feature documentation (current state)
- **[/api](./reference/api)** - API documentation and endpoints
- **[/guides](./reference/guides)** - How-to guides, tutorials, and examples
- **[/development](./reference/development)** - Development workflows, patterns, and style guides

### [/planning](./planning)
**Active planning documents and future roadmaps**

- **[/strategy](./planning/strategy)** - Business and product strategy
- **[/roadmap](./planning/roadmap)** - Feature roadmaps and future enhancements
- **[/tasks](./planning/tasks)** - Active implementation tasks and plans

### [/projects](./projects)
**Project-specific documentation for major features**

- **[/claude-code](./projects/claude-code)** - Claude Code integration documentation
- **[/mcp-integration](./projects/mcp-integration)** - Model Context Protocol (MCP) implementation
- **[/multi-tenant](./projects/multi-tenant)** - Multi-tenant SaaS infrastructure
- **[/google-workspace](./projects/google-workspace)** - Google Workspace MCP integration
- **[/visual-workflow-builder](./projects/visual-workflow-builder)** - Visual workflow builder feature

### [/archive](./archive)
**Historical documentation for reference**

- **[/iterations](./archive/iterations)** - Old versions and iterations of documents
- **[/completed-tasks](./archive/completed-tasks)** - Finished implementation documentation
- **[/legacy-strategy](./archive/legacy-strategy)** - Superseded strategy documents
- **[/generated](./archive/generated)** - Auto-generated project artifacts

## 🚀 Quick Start Guide

### For Developers

1. **New to AllSpark?** Start with [Architecture Overview](./reference/architecture/overview.md)
2. **Setting up development?** See [Docker Guide](./reference/deployment/docker.md)
3. **Building features?** Check [Development Workflows](./reference/development/feature-development.md)
4. **Working with AI?** Read [AI Integration](./reference/features/ai-integration.md)

### For DevOps/Deployment

1. **Local setup:** [Docker Development](./reference/deployment/docker.md)
2. **Production deployment:** [Multi-tenant Setup](./projects/multi-tenant/docker-swarm-production-plan.md)
3. **Security:** [Security Checklist](./reference/deployment/security-checklist.md)
4. **Monitoring:** [Monitoring Setup](./reference/deployment/monitoring.md)

### For Product/Strategy

1. **Product vision:** [Platform Strategy](./planning/strategy/allspark-platform-strategy-v2.md)
2. **Monetization:** [Monetization Strategy](./planning/strategy/allspark-monetization-strategy.md)
3. **Roadmap:** [Feature Roadmaps](./planning/roadmap/)
4. **Market analysis:** [Market Analysis](./planning/strategy/market-analysis.md)

## 🔍 Finding Information

### By Feature
- **Claude Code:** All documentation in [/projects/claude-code](./projects/claude-code)
- **MCP Integration:** See [/projects/mcp-integration](./projects/mcp-integration)
- **Multi-tenant/SaaS:** Check [/projects/multi-tenant](./projects/multi-tenant)
- **Chat System:** [Chat Component Guide](./reference/features/chat-component.md)
- **AI Agents:** [AI Agents Documentation](./reference/features/ai-agents-complete.md)

### By Task
- **API Integration:** [API Documentation](./reference/api/)
- **Testing:** [Browser Testing Guide](./reference/features/browser-testing-self-healing.md)
- **Debugging:** [Debugging Workflow](./reference/development/debugging.md)
- **Code Style:** [Style Guides](./reference/development/)

## 📝 Documentation Standards

When adding or updating documentation:

1. **Place documents in the correct directory:**
   - Technical reference → `/reference`
   - Future plans → `/planning`
   - Feature-specific → `/projects/{feature-name}`
   - Old/outdated → `/archive`

2. **Use clear naming:**
   - Descriptive filenames (e.g., `docker-swarm-setup.md` not `setup.md`)
   - Include version numbers if iterating (e.g., `requirements-v2.md`)

3. **Keep documents current:**
   - Update existing docs rather than creating new versions
   - Move outdated content to `/archive`
   - Remove duplicate information

4. **Cross-reference related docs:**
   - Link to related documentation
   - Maintain topic coherence within project directories

## 🤖 For AI Assistants

When working with this codebase:

1. **Check current implementation:** Look in `/reference` for how things work now
2. **Understand the plan:** Review `/planning` for upcoming changes
3. **Find project details:** Deep dive into `/projects` for specific features
4. **Avoid outdated info:** Documents in `/archive` are historical only

Key project entry points:
- [CLAUDE.md](../CLAUDE.md) - Project-specific AI instructions
- [Architecture Overview](./reference/architecture/overview.md) - System design
- [Development Patterns](./reference/development/ui-components.md) - Code patterns
- [Active Roadmap](./planning/roadmap/) - What's being built next