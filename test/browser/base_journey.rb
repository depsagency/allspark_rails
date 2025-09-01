# frozen_string_literal: true

require_relative 'helpers/journey_helper'

class BaseJourney
  include JourneyHelper

  def initialize
    setup_session
  end

  def run
    raise NotImplementedError, "Subclasses must implement the run method"
  end

  def cleanup
    teardown_session
  end

  protected

  def with_error_handling
    yield
  rescue => e
    screenshot("error_#{self.class.name.underscore}")
    raise e
  end

  def step(description)
    puts "\n→ #{description}"
    yield
  end
end