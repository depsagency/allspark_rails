# Enhanced Tool Call Display in Chat Components

## Overview

This enhancement improves the display of tool calls in chat messages by formatting them as proper markdown instead of showing raw JSON strings. The improvement applies to both the Claude Code chat component and the general chat message component.

## Features

### Enhanced Tool Call Formatting

Tool calls are now displayed with:
- **Clear section headers** with emojis for easy identification
- **Structured parameter display** with proper formatting
- **Code syntax highlighting** for code parameters
- **JSON formatting** for complex objects
- **Error handling** with fallback display options

### Display Examples

#### Tool Usage
```
🛠️ Tool Usage: Read

Parameters:
- **file_path**: `/app/config/routes.rb`
- **limit**: `50`
```

#### Tool Results
```
✅ Tool Result
```json
{
  "success": true,
  "files_found": 5,
  "data": ["file1.rb", "file2.rb"]
}
```

#### Tool Errors
```
❌ Tool Error
```
File not found: /invalid/path.rb
```

## Implementation Details

### Components Updated

1. **`Agents::ClaudeCodeMessageComponent`**
   - Enhanced `extract_text_from_content_blocks` method
   - Added `format_tool_use_block` and `format_tool_result_block` methods
   - Added backward compatibility with `format_tool_use_hash` and `format_tool_result_hash`

2. **`Chat::MessageComponent`**
   - Added `formatted_content` method to detect and format tool calls
   - Added support for both SDK-style and hash-style tool calls
   - Backward compatible with existing simple chat messages

### Key Methods

#### Tool Use Formatting
- Displays tool name with emoji
- Lists parameters with appropriate formatting:
  - Simple values: inline code blocks
  - Multi-line strings: code blocks
  - Complex objects: JSON code blocks
- Handles edge cases with error recovery

#### Tool Result Formatting
- Differentiates between successful results and errors
- Attempts to parse and format JSON responses
- Falls back to plain text for non-JSON content
- Uses appropriate emoji indicators

### Error Handling

The implementation includes robust error handling:
- Graceful fallback for serialization errors
- Escaping of special markdown characters
- Safe handling of malformed JSON
- Fallback to `.inspect` for complex objects

## Usage

### Claude Code Messages

Tool calls are automatically formatted when using the Claude Code SDK message objects:

```ruby
render Agents::ClaudeCodeMessageComponent.new(
  message: claude_code_message,
  variant: :assistant
)
```

### Regular Chat Messages

Tool calls are detected and formatted in regular chat messages:

```ruby
render Chat::MessageComponent.new(
  message: chat_message,
  current_user: user
)
```

### Hash-based Tool Calls

The system also supports hash-based tool calls for backward compatibility:

```ruby
message = {
  'tool_calls' => [
    {
      'name' => 'Read',
      'input' => { 'file_path' => '/app/config/routes.rb' }
    }
  ]
}
```

## Benefits

1. **Better User Experience**: Tool calls are now human-readable and well-formatted
2. **Improved Debugging**: Clear display of parameters and results
3. **Consistent Styling**: Uses the existing prose styling system
4. **Backward Compatibility**: Works with existing message formats
5. **Error Resilience**: Handles malformed data gracefully

## Technical Notes

- Uses Redcarpet for markdown rendering (already included in the application)
- Leverages existing prose CSS classes for consistent styling
- Maintains compatibility with both SDK-style and hash-style tool calls
- Includes comprehensive error handling for production reliability