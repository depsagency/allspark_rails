# Session Cookie Separation

## Overview

Builder and Target containers use different session cookie names to allow simultaneous login to both applications without conflicts.

## Cookie Configuration

### Session Cookies
- **Builder** (port 3001): `_allspark_builder_session`
- **Target** (port 3000): `_allspark_target_session`

### Remember Me Cookies (Devise)
- **Builder**: `remember_allspark_builder_user_token`
- **Target**: `remember_allspark_target_user_token`

## Implementation

### Session Store (`config/initializers/session_store.rb`)
```ruby
container_role = ENV['CONTAINER_ROLE'] || 'builder'

session_key = case container_role
when 'builder', 'builder_sidekiq'
  '_allspark_builder_session'
when 'target', 'target_sidekiq'
  '_allspark_target_session'
else
  '_allspark_session'
end

Rails.application.config.session_store :cookie_store, 
  key: session_key
```

### Devise Configuration (`config/initializers/devise.rb`)
```ruby
remember_key = case container_role
when 'builder', 'builder_sidekiq'
  'remember_allspark_builder_user_token'
when 'target', 'target_sidekiq'
  'remember_allspark_target_user_token'
else
  'remember_user_token'
end

config.rememberable_options = { key: remember_key }
```

## Benefits

1. **Simultaneous Login**: Log into both applications at the same time
2. **Independent Sessions**: Actions in one don't affect the other
3. **No Cookie Conflicts**: Different cookie names prevent overwrites
4. **Remember Me Works**: Separate remember tokens for each environment

## Testing

1. Open http://localhost:3001 (Builder)
2. Login with admin@example.com
3. Open http://localhost:3000 (Target) in same browser
4. Login with admin@example.com
5. Both sessions remain active independently

## Browser Developer Tools

To verify cookie separation:
1. Open browser developer tools (F12)
2. Go to Application/Storage → Cookies
3. You should see:
   - `_allspark_builder_session` for localhost:3001
   - `_allspark_target_session` for localhost:3000