# MCP Configuration Setup Tutorial

This step-by-step guide will help you set up MCP (Model Context Protocol) configurations to enhance your AI assistants and Claude Code sessions with external tools and services.

## Prerequisites

Before starting, ensure you have:
- An active AllSpark account
- API keys/tokens for services you want to integrate
- Basic understanding of the services you're connecting

## Tutorial 1: Setting Up Linear Integration

Linear is a modern issue tracking tool. This integration allows your AI to create, update, and query Linear issues.

### Step 1: Get Your Linear API Key

1. Log into [Linear](https://linear.app)
2. Go to **Settings** → **API** → **Personal API keys**
3. Click **Create key**
4. Copy the generated key (starts with `lin_api_`)

### Step 2: Create the Configuration

1. Navigate to **MCP Configurations** in AllSpark

   ![MCP Configurations Page](./images/mcp-configs-page.png)

2. Find the **Linear** template in the Available Templates section

   ![Linear Template](./images/linear-template.png)

3. Click **Use Template**

4. Fill in the configuration form:
   - **Configuration Name**: "Linear - [Your Workspace Name]"
   - **LINEAR_API_KEY**: Paste your API key from Step 1

   ![Linear Configuration Form](./images/linear-config-form.png)

5. Click **Create Configuration**

### Step 3: Test the Configuration

1. Find your new Linear configuration in the list
2. Click the menu (⋮) → **Test Connection**

   ![Test Connection](./images/test-connection.png)

3. You should see "Connection successful"

### Step 4: Use in Claude Code

Start a new Claude Code session and try:

```
Show me my assigned Linear issues

Create a new Linear issue:
Title: Update user documentation
Description: Add examples for the new API endpoints
Project: Backend
```

## Tutorial 2: Custom HTTP API Integration

This tutorial shows how to connect a custom REST API.

### Step 1: Gather API Information

You'll need:
- API endpoint URL
- Authentication method (Bearer token, API key, etc.)
- Any required headers

### Step 2: Create Custom Configuration

1. Go to **MCP Configurations** → **New Configuration**

2. Fill in the basic information:
   - **Configuration Name**: "My Company API"
   - **Server Type**: Select `http`

3. Configure the server settings:
   - **Endpoint**: `https://api.mycompany.com/mcp`
   - **Headers**: 
     ```json
     {
       "Authorization": "Bearer your-api-token",
       "Content-Type": "application/json"
     }
     ```

   ![HTTP Configuration](./images/http-config.png)

4. Click **Create Configuration**

### Step 3: Test and Verify

1. Use the **Test Connection** feature
2. Check that you receive a successful response
3. If it fails, verify:
   - Endpoint URL is correct
   - Authentication credentials are valid
   - API is accessible from AllSpark

## Tutorial 3: GitHub Integration

Connect GitHub to manage repositories, issues, and pull requests.

### Step 1: Create GitHub Personal Access Token

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens**
2. Click **Generate new token (classic)**
3. Select scopes:
   - `repo` (full control of repositories)
   - `read:org` (read organization data)
4. Generate and copy the token

### Step 2: Configure in AllSpark

1. Use the **GitHub** template
2. Enter your token in the `GITHUB_TOKEN` field
3. Create the configuration

### Step 3: Example Usage

In Claude Code:
```
List my GitHub repositories

Show open issues in owner/repo

Create a pull request in myorg/myrepo from feature-branch to main
Title: Add new feature
Description: This PR implements...
```

## Tutorial 4: Local Tool Integration (stdio)

This example shows how to integrate a local command-line tool.

### Step 1: Create a Simple Script

Create a local script `/usr/local/bin/my-tool`:

```bash
#!/bin/bash
# Simple tool that processes commands

case "$1" in
  "list")
    echo "Item 1"
    echo "Item 2"
    ;;
  "add")
    echo "Added: $2"
    ;;
  *)
    echo "Usage: my-tool [list|add <item>]"
    ;;
esac
```

Make it executable:
```bash
chmod +x /usr/local/bin/my-tool
```

### Step 2: Create stdio Configuration

1. Go to **New Configuration**
2. Configure:
   - **Name**: "My Local Tool"
   - **Server Type**: `stdio`
   - **Command**: `/usr/local/bin/my-tool`
   - **Arguments**: `[]` (empty array)
   - **Environment Variables**: (optional)
     ```json
     {
       "TOOL_CONFIG": "/path/to/config"
     }
     ```

### Step 3: Important Notes

- **Claude Code**: stdio tools work directly
- **Assistants**: Currently show "Bridge Required" (coming soon)

## Advanced Configuration

### Using Environment Variables

For sensitive data, use environment variable references:

```json
{
  "API_KEY": "${MY_SERVICE_API_KEY}",
  "BASE_URL": "${MY_SERVICE_URL:-https://default.com}"
}
```

Variables are resolved from AllSpark's environment when the configuration is used.

### WebSocket Configuration

For real-time services:

1. **Server Type**: `websocket`
2. **Endpoint**: `wss://realtime.service.com/socket`
3. **Headers**: Include any auth headers

### Server-Sent Events (SSE)

For streaming APIs:

1. **Server Type**: `sse`  
2. **URL**: `https://api.service.com/events`
3. **Headers**: Authentication headers

## Troubleshooting Common Issues

### "Connection Failed" Errors

1. **Check network connectivity**
   - Is the service accessible from AllSpark's network?
   - Are there firewall rules blocking access?

2. **Verify credentials**
   - Has the API key/token expired?
   - Are you using the correct authentication format?

3. **Validate URL format**
   - HTTP/HTTPS for http/sse types
   - WS/WSS for websocket type
   - Full path including any base paths

### "Command Not Found" (stdio)

1. **Check command path**
   - Use full absolute paths
   - Verify the command exists in the Claude Code environment

2. **Check permissions**
   - Is the command executable?
   - Does the Claude Code process have access?

### Configuration Not Available in Session

1. **Is it enabled?**
   - Check the configuration shows "Active" badge

2. **Refresh the session**
   - Start a new Claude Code session
   - Configurations are loaded at session start

## Best Practices

1. **Name configurations clearly**
   - Include the service name
   - Add environment/workspace if multiple

2. **Test immediately after creation**
   - Verify connections work before using
   - Fix any issues while context is fresh

3. **Document custom configurations**
   - Add notes about what endpoints do
   - Include example commands

4. **Regular maintenance**
   - Review and update credentials periodically
   - Remove unused configurations
   - Update endpoints if APIs change

## Next Steps

- Explore other available templates
- Share configurations with your team (instance-level configs)
- Build custom MCP servers for your specific needs
- Check the [API documentation](../api/mcp-configurations.md) for automation

## Getting Help

If you encounter issues:

1. Check the configuration test results
2. Review AllSpark logs for detailed errors
3. Consult the service's MCP documentation
4. Contact support with configuration details (without secrets)