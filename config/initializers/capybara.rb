# frozen_string_literal: true

if Rails.env.test?
  begin
    require 'capybara'
    require 'cuprite'

    Capybara.register_driver :cuprite do |app|
      Cuprite::Driver.new(app,
        window_size: [1200, 800],
        browser_options: {
          'no-sandbox': true,
          'disable-dev-shm-usage': true,
          'disable-gpu': true,
          'disable-background-timer-throttling': true,
          'disable-backgrounding-occluded-windows': true,
          'disable-renderer-backgrounding': true
        },
        inspector: true,
        headless: true,
        timeout: 30,
        process_timeout: 20
      )
    end

    Capybara.default_driver = :cuprite
    Capybara.javascript_driver = :cuprite
  rescue LoadError
    # Cuprite is only available in test environment
  end
end