# frozen_string_literal: true

module Chat
  # @label Simple Chat Message Examples
  class SimpleMessagePreview < Lookbook::Preview
    # @label Message Styles
    def message_styles
      render_with_template(
        template: "lookbook/chat/message_styles",
        locals: {}
      )
    end
  end
end