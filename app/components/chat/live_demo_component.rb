# frozen_string_literal: true

module Chat
  class LiveDemoComponent < ::BaseComponent
    def initialize(room_name: "lookbook-demo")
      @room_name = room_name
    end
    
    private
    
    attr_reader :room_name
  end
end