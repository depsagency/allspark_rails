class TerminalController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :test, :simple ]

  def test
    # Simple test page for xterm.js
    render layout: false
  end

  def simple
    # Even simpler test using application.js
    render layout: false
  end
end
