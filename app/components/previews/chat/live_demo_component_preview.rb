# frozen_string_literal: true

module Chat
  # @label Live Chat Demo
  class LiveDemoComponentPreview < Lookbook::Preview
    # @label Interactive Chat
    # @display bg_color "#f3f4f6"
    def interactive
      render Chat::LiveDemoComponent.new(room_name: "lookbook-demo-#{Time.current.strftime('%Y%m%d')}")
    end
    
    # @label Private Room
    # @display bg_color "#f3f4f6"
    def private_room
      # Each preview creates its own room
      render Chat::LiveDemoComponent.new(room_name: "private-#{SecureRandom.hex(4)}")
    end
  end
end