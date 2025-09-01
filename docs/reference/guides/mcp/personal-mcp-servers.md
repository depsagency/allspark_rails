# Personal MCP Servers User Guide

## Overview

Personal MCP (Model Context Protocol) Servers allow you to create private, user-specific MCP servers that provide custom tools and capabilities to your AI assistants. Unlike system-wide MCP servers managed by administrators, personal MCP servers are completely private to your account and can be configured with your own credentials and endpoints.

## What are MCP Servers?

MCP (Model Context Protocol) is a protocol that allows AI assistants to connect to external services and tools. MCP servers expose functions that your AI assistants can call to:

- Access external APIs and services
- Retrieve real-time data
- Perform complex computations
- Integrate with third-party tools
- Execute custom business logic

## Getting Started

### Accessing Personal MCP Servers

1. **Navigate to Your Profile**
   
   Log in to AllSpark and navigate to your user profile page.

   ![User Profile Page](user_profile_page.png)
   
   **Key Elements:**
   - **Profile Information**: Your account details and settings
   - **MCP Servers Link**: Click this to access your personal MCP server management
   - **Navigation Menu**: Access to other AllSpark features

2. **Access MCP Servers Section**
   
   Click on the "MCP Servers" link in your profile to access the personal MCP servers management interface.

   ![Personal MCP Servers Page](personal_mcp_servers_page.png)

### Understanding the MCP Servers Interface

The Personal MCP Servers page is divided into several key sections:

#### Health Overview Dashboard
At the top of the page, you'll see four statistics cards:

- **Personal Servers**: Total count of your private MCP servers
- **Active**: Number of currently active and functioning servers
- **System Servers**: Count of system-wide servers available to all users
- **Health**: Overall health percentage of your servers

#### Personal Servers Section (Left Panel)
This section manages your private MCP servers:

- **Server List**: Shows all your personal MCP servers
- **Server Details**: For each server, you can see:
  - Server name and endpoint URL
  - Authentication type (API Key, Bearer Token, OAuth, None)
  - Number of available tools
  - Status badge (Active, Inactive, Error)
  - "Private" label indicating user-specific access
- **Management Options**: Each server has a dropdown menu with:
  - **Test Connection**: Verify the server is responding
  - **Edit**: Modify server configuration
  - **Delete**: Remove the server permanently

#### System Servers Section (Right Panel)
This section shows system-wide MCP servers:

- **Read-Only Access**: You can view but not modify these servers
- **Shared Resources**: Available to all users in the system
- **Tool Information**: View available tools and their descriptions
- **System-wide Label**: Indicates these are managed by administrators

## Creating a Personal MCP Server

### Step 1: Open the Creation Modal

Click the "Add Personal Server" button in the top-right corner or within the Personal Servers section.

### Step 2: Fill in Basic Information

![Personal MCP Server Form](personal_server_form_filled.png)

**Form Fields Explained:**

1. **Server Name** (Required)
   - **Purpose**: A friendly name to identify your server
   - **Example**: "My Weather API Server", "Personal Database Tools"
   - **Usage**: This name appears in your server list and assistant configurations

2. **Endpoint URL** (Required)
   - **Purpose**: The base URL where your MCP server is hosted
   - **Format**: Must be a valid HTTPS URL ending in `/mcp/v1` or similar
   - **Example**: `https://my-mcp-server.example.com/mcp/v1`
   - **Note**: This is where AllSpark will connect to access your server's tools

3. **Status**
   - **Active**: Server is enabled and available to your assistants
   - **Inactive**: Server is disabled and won't be used by assistants
   - **Default**: New servers are created as Active

4. **Authentication Type**
   - **No Authentication**: For public or internal servers that don't require credentials
   - **API Key**: Most common - requires an API key for authentication
   - **Bearer Token**: Uses a bearer token in the Authorization header
   - **OAuth 2.0**: For servers requiring OAuth 2.0 authentication flow

### Step 3: Configure Authentication

Based on your selected authentication type, additional fields will appear:

#### API Key Authentication
- **API Key**: Enter your personal API key
- **API Key Header** (Optional): Custom header name (defaults to "Authorization")

#### Bearer Token Authentication
- **Bearer Token**: Enter your bearer token value

#### OAuth 2.0 Authentication
- Shows informational message that OAuth will be configured after server creation
- OAuth flow will be initiated when the server is first used

### Step 4: Review Privacy Notice

The form includes an important privacy notice:

> **Privacy Notice**: Personal MCP servers are private to your account. Credentials are encrypted and only accessible to your assistants. Server configurations are not shared with other users.

**Key Privacy Features:**
- **Encrypted Storage**: All credentials are encrypted in the database
- **User Isolation**: Only you and your assistants can access these servers
- **No Sharing**: Server configurations are never shared with other users
- **Secure Access**: Credentials are only decrypted when needed for API calls

### Step 5: Create the Server

Click "Add Personal Server" to create your server. The system will:

1. **Validate** your configuration
2. **Test** the connection to your server
3. **Discover** available tools from your server
4. **Encrypt** and store your credentials securely

## Managing Personal MCP Servers

### Editing a Server

1. Find your server in the Personal Servers list
2. Click the dropdown menu (three dots)
3. Select "Edit"
4. Modify any configuration options
5. Click "Update Server"

**What You Can Edit:**
- Server name and status
- Endpoint URL (will trigger tool re-discovery)
- Authentication credentials
- Authentication type

### Testing Server Connection

To verify your server is working correctly:

1. Find your server in the list
2. Click the dropdown menu
3. Select "Test Connection"

**Test Results:**
- **Success**: Server is responding and accessible
- **Failure**: Connection issues or authentication problems
- **Error Details**: Specific error messages help troubleshoot issues

### Deleting a Server

To permanently remove a personal MCP server:

1. Find your server in the list
2. Click the dropdown menu
3. Select "Delete"
4. Confirm the deletion when prompted

**⚠️ Warning**: Deletion is permanent and cannot be undone. Any assistants using this server will lose access to its tools.

## Understanding Server Status

### Status Indicators

- **🟢 Active**: Server is functioning normally and available to assistants
- **🟡 Inactive**: Server is disabled and won't be used
- **🔴 Error**: Server has connection or authentication issues

### Health Monitoring

The system continuously monitors your servers:

- **Connection Tests**: Regular health checks to ensure servers are responsive
- **Error Tracking**: Logs and tracks any connection failures
- **Performance Metrics**: Response time and reliability statistics
- **Tool Discovery**: Automatic detection of new or updated tools

## Using Personal MCP Servers with Assistants

Once you've created personal MCP servers, they become available to your AI assistants:

### Automatic Integration

- **Tool Discovery**: Your assistants automatically detect available tools
- **Scoped Access**: Only your assistants can access your personal servers
- **Dynamic Loading**: Tools are loaded on-demand when assistants need them
- **Error Handling**: Graceful fallback when servers are unavailable

### Assistant Configuration

In your assistant settings, you can:

- **Enable MCP Tools**: Turn on MCP integration for the assistant
- **Select Servers**: Choose which servers the assistant can access
- **Filter Tools**: Limit which tools from each server are available
- **Tool Preferences**: Set priorities for when multiple tools serve similar functions

## Security and Privacy

### Data Protection

- **Credential Encryption**: All API keys and tokens are encrypted using industry-standard encryption
- **Secure Transmission**: All communications use HTTPS/TLS encryption
- **Access Control**: Strict user isolation prevents cross-user access
- **Audit Logging**: All server access is logged for security monitoring

### Best Practices

1. **Use Strong Credentials**: Ensure your API keys and tokens are strong and unique
2. **Regular Rotation**: Periodically update your credentials
3. **Monitor Usage**: Review server logs and usage patterns
4. **Limit Scope**: Use credentials with minimal necessary permissions
5. **Test Regularly**: Verify your servers are working as expected

### Sharing and Collaboration

**Important**: Personal MCP servers cannot be shared with other users. If you need to share MCP capabilities:

- **Contact Administrators**: Request system-wide server creation
- **Instance Servers**: Use instance-specific servers for team collaboration
- **Documentation**: Share server configuration details for others to recreate

## Troubleshooting

### Common Issues

#### Connection Failures

**Symptoms**: Server shows "Error" status, connection tests fail

**Solutions**:
1. Verify endpoint URL is correct and accessible
2. Check authentication credentials
3. Ensure server is running and responding
4. Verify firewall and network settings
5. Check server logs for detailed error messages

#### Authentication Problems

**Symptoms**: "Unauthorized" or "Forbidden" errors

**Solutions**:
1. Verify API key or token is correct
2. Check credential format and headers
3. Ensure credentials have sufficient permissions
4. Test credentials directly with the server
5. Check for credential expiration

#### Tool Discovery Issues

**Symptoms**: Server connects but no tools are available

**Solutions**:
1. Verify server implements MCP protocol correctly
2. Check server's tool listing endpoint
3. Review server logs for discovery errors
4. Ensure tools are properly defined in server
5. Test tool discovery manually

#### Performance Issues

**Symptoms**: Slow responses, timeouts

**Solutions**:
1. Check server performance and load
2. Verify network connectivity and latency
3. Review server resource allocation
4. Consider server optimization
5. Check for rate limiting

### Getting Help

If you encounter issues with personal MCP servers:

1. **Documentation**: Review MCP protocol documentation
2. **Server Logs**: Check your server's logs for detailed error messages
3. **System Logs**: Administrators can review AllSpark connection logs
4. **Support**: Contact your AllSpark administrator for assistance
5. **Community**: Consult MCP community resources and forums

## Advanced Configuration

### Custom Headers and Options

For advanced MCP server configurations:

- **Custom Headers**: Add authentication headers beyond standard API keys
- **Request Timeouts**: Configure connection and response timeouts
- **Retry Logic**: Set retry parameters for failed requests
- **Rate Limiting**: Configure request rate limiting

### Protocol Versions

AllSpark supports multiple MCP protocol versions:

- **Version 1.0**: Standard MCP implementation
- **Future Versions**: Automatic detection and compatibility
- **Fallback**: Graceful handling of version mismatches

### Integration Patterns

Common patterns for personal MCP servers:

1. **API Wrapper**: Wrap existing APIs in MCP protocol
2. **Database Access**: Provide secure database query tools
3. **File Operations**: Enable file system access for assistants
4. **Custom Logic**: Implement business-specific functions
5. **External Services**: Connect to third-party services and tools

## Conclusion

Personal MCP servers provide a powerful way to extend your AI assistants with custom tools and capabilities while maintaining complete privacy and control. By following this guide, you can securely create, configure, and manage personal MCP servers that enhance your AI workflow.

Remember that personal MCP servers are a powerful feature that requires careful consideration of security and privacy. Always use strong credentials, monitor server access, and follow security best practices to ensure your data and services remain protected.