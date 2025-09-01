# frozen_string_literal: true

# Helper methods for system specs
module SystemHelpers
  def sign_in_user(user = nil)
    user ||= create(:user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Log in'
    expect(page).not_to have_content('Invalid Email or password')
    user
  end

  def sign_in_admin
    admin = create(:user, :admin)
    sign_in_user(admin)
    admin
  end

  def sign_out_user
    visit root_path
    click_link 'Logout' if page.has_link?('Logout')
  end

  def expect_flash_message(type, message = nil)
    within('.flash-messages, .alert, .notice, [data-flash]') do
      expect(page).to have_css(".alert-#{type}, .#{type}, [data-flash-type='#{type}']")
      expect(page).to have_content(message) if message
    end
  end

  def expect_page_title(title)
    expect(page).to have_title(title)
    expect(page).to have_css('h1', text: title)
  end

  def expect_current_path(path)
    expect(current_path).to eq(path)
  end

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script('jQuery.active').zero?
    end
  rescue Timeout::Error
    # If jQuery is not available, just wait a bit
    sleep 0.5
  end

  def wait_for_turbo
    expect(page).not_to have_css('[data-turbo-busy]')
  end

  def within_modal(&block)
    within('[role="dialog"], .modal, [data-modal]', &block)
  end

  def close_modal
    within_modal do
      if page.has_css?('[data-action*="modal#close"]')
        find('[data-action*="modal#close"]').click
      elsif page.has_css?('.btn-close, .close')
        find('.btn-close, .close').click
      else
        page.send_keys(:escape)
      end
    end
  end

  def fill_in_rich_text(locator, with:)
    find_field(locator).click
    find_field(locator).send_keys(with)
  end

  def attach_file_to_dropzone(file_path, dropzone_selector = '.dropzone')
    find(dropzone_selector).drop(file_path)
  end

  def expect_notification(type, message = nil)
    within('.toast, .notification, [data-notification]') do
      expect(page).to have_css(".alert-#{type}, .#{type}")
      expect(page).to have_content(message) if message
    end
  end

  def wait_for_notification
    expect(page).to have_css('.toast, .notification, [data-notification]')
  end

  def dismiss_notification
    within('.toast, .notification, [data-notification]') do
      if page.has_css?('[data-dismiss], .close, .btn-close')
        find('[data-dismiss], .close, .btn-close').click
      end
    end
  end

  # Real-time features testing
  def expect_live_update(selector, content = nil)
    expect(page).to have_css(selector)
    expect(page).to have_content(content) if content
  end

  def wait_for_websocket_connection
    sleep 0.5 # Give ActionCable time to connect
    expect(page.evaluate_script('typeof(consumer) !== "undefined"')).to be true
  end

  def simulate_user_online(user_id)
    page.evaluate_script(<<~JS)
      if (window.presenceChannel) {
        window.presenceChannel.handlePresenceUpdate({
          type: 'user_online',
          user: { id: #{user_id}, name: 'Test User' }
        });
      }
    JS
  end

  def simulate_notification(notification_data)
    page.evaluate_script(<<~JS)
      if (window.notificationsChannel) {
        window.notificationsChannel.handleNotification({
          type: 'new_notification',
          notification: #{notification_data.to_json}
        });
      }
    JS
  end

  # Form helpers with DaisyUI
  def select_from_daisy_select(value, from:)
    find("select[name='#{from}']").select(value)
  end

  def check_daisy_checkbox(locator)
    find("input[type='checkbox'][name='#{locator}']").set(true)
  end

  def uncheck_daisy_checkbox(locator)
    find("input[type='checkbox'][name='#{locator}']").set(false)
  end

  # File upload helpers
  def upload_file(file_path, input_selector = 'input[type="file"]')
    attach_file(input_selector, file_path, make_visible: true)
  end

  def expect_file_uploaded(filename)
    expect(page).to have_content(filename)
  end

  # Theme testing
  def switch_theme(theme)
    page.evaluate_script("document.documentElement.setAttribute('data-theme', '#{theme}')")
  end

  def expect_theme(theme)
    expect(page.evaluate_script("document.documentElement.getAttribute('data-theme')")).to eq(theme)
  end

  # Mobile testing helpers
  def simulate_mobile
    page.driver.resize_window(375, 667) # iPhone size
  end

  def simulate_tablet
    page.driver.resize_window(768, 1024) # iPad size
  end

  def simulate_desktop
    page.driver.resize_window(1920, 1080) # Desktop size
  end

  # Debugging helpers
  def screenshot(name = nil)
    name ||= "screenshot_#{Time.current.to_i}"
    page.save_screenshot("tmp/screenshots/#{name}.png")
    puts "Screenshot saved: tmp/screenshots/#{name}.png"
  end

  def debug_page
    puts page.html
    screenshot('debug')
  end

  def print_page_errors
    errors = page.evaluate_script('window.errors || []')
    puts "JavaScript errors: #{errors}" if errors.any?
  end
end
