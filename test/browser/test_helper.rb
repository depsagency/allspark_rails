require_relative '../test_helper'
require_relative '../application_system_test_case'

class BrowserTest < ApplicationSystemTestCase
  # Browser-specific test helpers
  
  def wait_for_selector(selector, count: nil, visible: true, timeout: 10)
    if count
      assert_selector(selector, count: count, visible: visible, wait: timeout)
    else
      assert_selector(selector, visible: visible, wait: timeout)
    end
  end
  
  def wait_for_no_selector(selector, timeout: 10)
    assert_no_selector(selector, wait: timeout)
  end
end