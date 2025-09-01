# Allow iframe embedding in development
if Rails.env.development?
  Rails.application.config.action_dispatch.default_headers.merge!({
    'X-Frame-Options' => 'ALLOWALL'
  })
end
