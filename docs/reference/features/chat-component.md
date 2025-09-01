# Chat Component System

This document provides a comprehensive guide to the real-time chat functionality built into the application.

## Overview

The chat system provides real-time messaging capabilities with the following features:
- **Real-time messaging** using ActionCable WebSockets
- **Chat threads** with multiple participants
- **Read receipts** and **typing indicators**
- **Markdown support** for rich text formatting
- **ViewComponent-based UI** for reusability
- **Interactive Lookbook previews** for development

## Architecture

### Database Schema

The chat system uses three main models:

#### ChatThread
- Represents a conversation between multiple users
- Can be standalone or associated with a context (polymorphic)
- Tracks creation and last activity

```ruby
ChatThread
├── id (UUID)
├── name (string)
├── created_by_id (UUID, references User)
├── context_type (string, optional)
├── context_id (UUID, optional)
├── last_activity_at (datetime)
└── timestamps
```

#### ChatMessage
- Individual messages within a thread
- Supports editing with history tracking
- Automatically broadcasts changes via ActionCable

```ruby
ChatMessage
├── id (UUID)
├── chat_thread_id (UUID)
├── user_id (UUID)
├── content (text)
├── edited (boolean)
├── edited_at (datetime)
└── timestamps
```

#### ChatThreadParticipant
- Join table tracking thread membership
- Stores read receipt timestamps
- Manages participant status

```ruby
ChatThreadParticipant
├── id (UUID)
├── chat_thread_id (UUID)
├── user_id (UUID)
├── last_read_at (datetime)
├── status (string)
└── timestamps
```

### Component Structure

The chat system is built using ViewComponent for modularity:

```
app/components/chat/
├── container_component.rb       # Main chat container with sidebar
├── thread_list_component.rb     # List of available threads
├── thread_component.rb          # Individual chat thread view
├── message_component.rb         # Single message display
├── demo_component.rb           # Static demos for Lookbook
└── live_demo_component.rb      # Interactive demo with real-time features
```

## Usage

### Basic Implementation

#### 1. Add Chat to a View

```erb
<!-- In any view where you want chat -->
<%= render Chat::ContainerComponent.new(
  user: current_user,
  thread_id: params[:thread_id]  # Optional: specific thread
) %>
```

#### 2. Create a Chat Thread

```ruby
# In controller or service
thread = ChatThread.create!(
  name: "Project Discussion",
  created_by: current_user
)

# Add participants
thread.add_participant(current_user)
thread.add_participant(other_user)
```

#### 3. Send Messages

Messages are sent via ActionCable, handled automatically by the JavaScript controller:

```javascript
// This happens automatically when user types and hits enter
// Handled by chat_controller.js
```

### Contextual Chat

Associate chat threads with any model:

```ruby
# Example: Add chat to a Project
class Project < ApplicationRecord
  has_many :chat_threads, as: :context
  
  def discussion_thread
    chat_threads.find_or_create_by!(name: "#{name} Discussion") do |thread|
      thread.created_by = creator
    end
  end
end

# In the view
<%= render Chat::ThreadComponent.new(
  thread: @project.discussion_thread,
  user: current_user
) %>
```

### Markdown Support

Messages support full Markdown formatting via Redcarpet:

- **Bold text** with `**text**`
- *Italic text* with `*text*`
- `Code snippets` with backticks
- Links are automatically detected
- Code blocks with triple backticks
- Tables, strikethrough, and more

Configuration in `app/channels/live_demo_chat_channel.rb`:

```ruby
def render_markdown(text)
  renderer = Redcarpet::Render::HTML.new(
    filter_html: true,
    safe_links_only: true,
    hard_wrap: true,
    link_attributes: { target: '_blank', rel: 'noopener' }
  )
  
  markdown = Redcarpet::Markdown.new(renderer,
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true
  )
  
  markdown.render(text).strip
end
```

## Real-time Features

### ActionCable Channels

The system uses two ActionCable channels:

#### ChatChannel
- Handles authenticated user chat
- Manages thread subscriptions
- Broadcasts messages, edits, and deletions

```ruby
# Subscribed automatically when viewing a thread
# app/channels/chat_channel.rb
```

#### LiveDemoChatChannel
- Powers the Lookbook preview demos
- Allows guest connections for testing
- Tracks online users with Redis

### Typing Indicators

Real-time typing status is broadcast to all participants:

```javascript
// Automatically triggered on input
// Shows "User is typing..." below messages
```

### Read Receipts

Messages are marked as read when:
- User opens the thread
- User sends a message
- Browser window gains focus

## UI Components

### Chat Layout

The chat interface uses a dedicated layout without app header/footer:

```erb
<!-- app/views/layouts/chat.html.erb -->
<!DOCTYPE html>
<html class="h-full">
  <body class="h-full">
    <%= yield %>
  </body>
</html>
```

### DaisyUI Chat Bubbles

Messages use DaisyUI's chat component styling:

```erb
<div class="chat chat-start">
  <div class="chat-image avatar">
    <!-- Avatar with centered initials -->
  </div>
  <div class="chat-header">
    User Name
    <time class="text-xs opacity-50">12:45</time>
  </div>
  <div class="chat-bubble">
    Message content
  </div>
</div>
```

### Responsive Design

- **Mobile**: Full-screen chat with collapsible sidebar
- **Tablet**: Split view with narrow thread list
- **Desktop**: Full sidebar with thread details

## Development with Lookbook

### Static Previews

View different chat states in Lookbook:

```ruby
# app/components/previews/chat/demo_component_preview.rb
class Chat::DemoComponentPreview < Lookbook::Preview
  def default
    render Chat::DemoComponent.new
  end
  
  def with_messages
    render Chat::DemoComponent.new(variant: :with_messages)
  end
  
  def typing_indicator
    render Chat::DemoComponent.new(variant: :typing)
  end
end
```

### Interactive Demo

Test real-time features without authentication:

```ruby
# Visit /lookbook/inspect/chat/live_demo_component/default
# Multiple users can join and chat in real-time
```

## JavaScript Controllers

### chat_controller.js
Manages authenticated chat sessions:
- Establishes ActionCable connection
- Handles message sending/receiving
- Manages typing indicators
- Updates read receipts

### live_chat_controller.js
Powers the Lookbook demo:
- Creates guest sessions with sessionStorage
- Maintains user list with Redis
- Handles reconnection gracefully

### chat_container_controller.js
Manages the overall layout:
- Thread selection
- Sidebar toggling
- New thread creation

## Styling and Customization

### CSS Classes

Key classes for customization:

```css
/* Chat containers */
.chat-container     /* Main wrapper */
.chat-sidebar       /* Thread list panel */
.chat-main          /* Message area */
.chat-messages      /* Scrollable message list */

/* Messages */
.chat              /* Message wrapper */
.chat-start        /* Left-aligned (other users) */
.chat-end          /* Right-aligned (current user) */
.chat-bubble       /* Message bubble */
.chat-bubble-primary /* Styled for current user */

/* Components */
.chat-thread-item  /* Thread in sidebar */
.chat-typing-indicator /* Typing status */
```

### Theme Support

Automatically adapts to light/dark themes:
- Uses semantic color variables
- Respects DaisyUI theme selection
- Maintains readability in all themes

## Performance Considerations

### Message Loading
- Loads last 50 messages by default
- Implements virtual scrolling for large threads
- Lazy loads older messages on scroll

### WebSocket Optimization
- Single connection per user
- Automatic reconnection on disconnect
- Efficient message broadcasting

### Caching
- Thread list cached for 5 minutes
- Message render caching with Markdown
- User presence tracked in Redis

## Security

### Authorization
- Thread access verified on subscription
- Message editing limited to author
- Participant management restricted

### Content Security
- Markdown sanitized server-side
- HTML filtered to prevent XSS
- Links open in new tabs with `noopener`

## Testing

### Browser Testing

Test chat functionality with the browser testing framework:

```bash
# Test chat UI
docker-compose exec web rake browser:test[/chat]

# Run full chat journey
docker-compose exec web rake browser:journey[chat_test]

# Debug with screenshots
docker-compose exec web rake browser:diagnose[/chat]
```

### Manual Testing

1. Open two browser windows (regular + incognito)
2. Log in as different users
3. Navigate to `/chat`
4. Send messages between users
5. Verify real-time updates

## Troubleshooting

### Messages Not Appearing
1. Check ActionCable connection in browser console
2. Verify Redis is running: `docker-compose ps redis`
3. Check Rails logs for broadcast messages

### Typing Indicators Stuck
- Indicators auto-clear after 3 seconds
- Check for JavaScript errors
- Verify WebSocket connection

### Chat Not Loading
1. Ensure migrations are run
2. Check for participant records
3. Verify user authentication

## Configuration

### Environment Variables

```bash
# Redis for ActionCable
REDIS_URL=redis://localhost:6379/1

# ActionCable settings
ACTION_CABLE_URL=/cable
ACTION_CABLE_ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com
```

### Initializers

Key configuration files:
- `config/cable.yml` - ActionCable adapters
- `config/initializers/action_cable.rb` - Connection settings
- `app/channels/application_cable/connection.rb` - Authentication

## Future Enhancements

Potential improvements to consider:

1. **File Uploads** - Attach images and documents
2. **Message Reactions** - Emoji reactions to messages
3. **Voice/Video** - WebRTC integration
4. **Message Search** - Full-text search across threads
5. **Notifications** - Push notifications for mentions
6. **Thread Archives** - Export chat history
7. **Moderation Tools** - Admin message management
8. **Custom Emojis** - Organization-specific emoji sets

## API Reference

### Model Methods

```ruby
# ChatThread
thread.add_participant(user)
thread.remove_participant(user)
thread.participant?(user)
thread.mark_as_read_for(user)
thread.unread_count_for(user)
thread.recent_messages

# ChatMessage
message.edit!(new_content)
message.edited?

# User
user.chat_threads
user.unread_chat_threads
```

### JavaScript API

```javascript
// Chat Controller (Stimulus)
this.channel.perform('send_message', { content: text })
this.channel.perform('typing', { is_typing: true })
this.channel.perform('mark_as_read')
this.channel.perform('edit_message', { message_id: id, content: text })
this.channel.perform('delete_message', { message_id: id })
```

## Summary

The chat component system provides a complete real-time messaging solution that's:
- **Easy to integrate** - Drop-in ViewComponents
- **Feature-rich** - Typing, receipts, markdown, and more
- **Developer-friendly** - Lookbook previews and browser testing
- **Production-ready** - Secure, performant, and scalable

For questions or issues, refer to the browser testing logs or check the Rails console for debugging information.