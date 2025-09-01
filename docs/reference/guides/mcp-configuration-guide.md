# MCP Configuration Guide

## Overview

This guide explains how to configure and use Model Context Protocol (MCP) servers with AllSpark, enabling your AI assistants to connect with external tools like Linear, GitHub, and more.

## What is MCP?

Model Context Protocol (MCP) is an open standard that allows AI assistants to securely connect to external data sources and tools. MCP servers provide a standardized way for AI models to:

- Access external APIs (Linear issues, GitHub repositories)
- Execute commands and workflows
- Retrieve real-time data
- Perform actions on behalf of users

## Setting Up MCP Servers

### Prerequisites

1. **AllSpark Application**: Running AllSpark with MCP Bridge enabled
2. **API Keys**: Valid API keys for the services you want to connect
3. **MCP Server**: The appropriate MCP server for your service

### Step 1: Install MCP Servers

MCP servers are typically Node.js packages that you install in your AllSpark environment:

```bash
# For Linear integration
docker-compose exec web npm install -g @linear/mcp-server

# For GitHub integration  
docker-compose exec web npm install -g @github/mcp-server
```

Alternatively, add them to your `package.json`:

```json
{
  "dependencies": {
    "@linear/mcp-server": "^1.0.0",
    "@github/mcp-server": "^1.0.0"
  }
}
```

### Step 2: Configure Environment Variables

Add the required API keys to your `.env` file:

```bash
# Linear API Key (get from https://linear.app/settings/api)
LINEAR_API_KEY=your_linear_api_key_here

# GitHub Token (get from https://github.com/settings/tokens)
GITHUB_TOKEN=your_github_token_here
```

### Step 3: Create MCP Configuration

Navigate to your AllSpark settings and create a new MCP configuration:

1. **Go to Settings**: Visit `/settings/mcp` in your AllSpark app
2. **Add New Configuration**: Click "Add MCP Server"
3. **Fill Configuration Details**:

#### Linear Configuration Example

```json
{
  "name": "Linear Issues",
  "command": "linear-mcp",
  "args": [],
  "env": {
    "LINEAR_API_KEY": "your_linear_api_key"
  },
  "server_type": "stdio",
  "enabled": true
}
```

#### GitHub Configuration Example

```json
{
  "name": "GitHub Repositories",
  "command": "github-mcp",
  "args": ["--repo", "owner/repo-name"],
  "env": {
    "GITHUB_TOKEN": "your_github_token"
  },
  "server_type": "stdio", 
  "enabled": true
}
```

## Available MCP Servers

### Linear MCP Server

**Purpose**: Manage Linear issues, projects, and teams

**Installation**:
```bash
npm install -g @linear/mcp-server
```

**Configuration**:
- **Command**: `linear-mcp`
- **Required Environment**: `LINEAR_API_KEY`
- **API Key Source**: [Linear Settings > API](https://linear.app/settings/api)

**Available Tools**:
- `list_issues`: Get issues assigned to you or by filter
- `create_issue`: Create new issues
- `update_issue`: Update existing issues  
- `list_projects`: Get available projects
- `list_teams`: Get team information

**Example Usage**:
```
AI: "Show me my open Linear issues"
AI: "Create a new issue: Fix login bug in the auth module"
AI: "Update issue LIN-123 to mark it as in progress"
```

### GitHub MCP Server

**Purpose**: Access GitHub repositories, issues, and pull requests

**Installation**:
```bash
npm install -g @github/mcp-server
```

**Configuration**:
- **Command**: `github-mcp`
- **Required Environment**: `GITHUB_TOKEN`
- **API Key Source**: [GitHub Settings > Tokens](https://github.com/settings/tokens)

**Available Tools**:
- `list_repos`: Get repository information
- `list_issues`: Get issues from repositories
- `create_issue`: Create new GitHub issues
- `list_prs`: Get pull requests
- `get_file`: Read file contents from repository

**Example Usage**:
```
AI: "List all open issues in my main repository"
AI: "Show me the contents of README.md from the main branch"
AI: "Create an issue to update the documentation"
```

## Configuration Options

### Basic Configuration

Every MCP configuration requires these fields:

```json
{
  "name": "Human-readable name",
  "command": "executable-command",
  "args": ["array", "of", "arguments"],
  "env": {
    "ENV_VAR": "value"
  },
  "server_type": "stdio",
  "enabled": true
}
```

### Advanced Configuration

#### Process Management

```json
{
  "auto_restart": true,
  "max_restarts": 3,
  "health_check_interval": 60,
  "process_timeout": 30
}
```

#### Security Settings

```json
{
  "allowed_tools": ["list_issues", "create_issue"],
  "rate_limit": {
    "requests_per_minute": 60,
    "burst": 10
  }
}
```

## Using MCP Tools with AI Assistants

### In Claude Code Sessions

When you have MCP servers configured, your AI assistants can automatically use them:

```
User: "What Linear issues are assigned to me?"