# frozen_string_literal: true

class LiveDemoChatChannel < ApplicationCable::Channel
  def subscribed
    @room = params[:room] || "default"
    @users = {}
    
    stream_from "live_demo_chat_#{@room}"
    
    # Track connected users for this room
    redis.sadd("live_demo_chat:#{@room}:users", connection_id)
  end
  
  def unsubscribed
    # Remove user from room
    redis.srem("live_demo_chat:#{@room}:users", connection_id)
    
    # Get user info before removing
    user_info = redis.hget("live_demo_chat:users", connection_id)
    if user_info
      user_data = JSON.parse(user_info)
      
      # Notify others that user left
      ActionCable.server.broadcast("live_demo_chat_#{@room}", {
        type: "user_left",
        user_name: user_data["name"],
        session_id: user_data["session_id"]
      })
      
      # Remove user info
      redis.hdel("live_demo_chat:users", connection_id)
    end
    
    # Broadcast updated users list
    broadcast_users_list
  end
  
  def join(data)
    # Store user info
    user_info = {
      name: data["user_name"],
      session_id: data["session_id"],
      color: data["user_color"] || "primary",
      joined_at: Time.current
    }
    
    Rails.logger.info "User joining with session_id: #{data["session_id"]}"
    
    redis.hset("live_demo_chat:users", connection_id, user_info.to_json)
    
    # Notify others that user joined
    ActionCable.server.broadcast("live_demo_chat_#{@room}", {
      type: "user_joined",
      user_name: data["user_name"],
      session_id: data["session_id"]
    })
    
    # Send current users list to all
    broadcast_users_list
  end
  
  def send_message(data)
    # Render markdown content
    rendered_content = render_markdown(data["content"])
    
    Rails.logger.info "Sending message with session_id: #{data["session_id"]}"
    
    ActionCable.server.broadcast("live_demo_chat_#{@room}", {
      type: "message",
      content: data["content"],
      rendered_content: rendered_content,
      user_name: data["user_name"],
      user_color: data["user_color"],
      session_id: data["session_id"],
      timestamp: Time.current
    })
  end
  
  def typing(data)
    ActionCable.server.broadcast("live_demo_chat_#{@room}", {
      type: "typing",
      is_typing: data["is_typing"],
      user_name: data["user_name"],
      session_id: data["session_id"]
    })
  end
  
  private
  
  def connection_id
    @connection_id ||= "#{@room}:#{SecureRandom.hex(8)}"
  end
  
  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_images: false,
      no_links: false,
      no_styles: true,
      safe_links_only: true,
      with_toc_data: false,
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener' }
    )
    
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: false,
      no_intra_emphasis: true
    )
    
    markdown.render(text).strip
  end
  
  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end
  
  def broadcast_users_list
    # Get all users in room
    user_ids = redis.smembers("live_demo_chat:#{@room}:users")
    users = user_ids.map do |id|
      user_json = redis.hget("live_demo_chat:users", id)
      JSON.parse(user_json) if user_json
    end.compact
    
    ActionCable.server.broadcast("live_demo_chat_#{@room}", {
      type: "users_list",
      users: users
    })
  end
end