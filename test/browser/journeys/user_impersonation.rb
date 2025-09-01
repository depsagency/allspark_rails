# frozen_string_literal: true

require_relative '../browser_test_helper'

class UserImpersonationJourney < BrowserTestCase
  test "admin can impersonate a user and view their perspective" do
    # Create test users
    admin = create(:user, :admin, email: 'admin@test.com', password: 'password123')
    regular_user = create(:user, email: 'user@test.com', first_name: 'Test', last_name: 'User')

    # 1. Admin logs in
    visit '/'
    click_on 'Sign In'
    fill_in 'Email', with: 'admin@test.com'
    fill_in 'Password', with: 'password123'
    click_on 'Log in'
    
    # Verify admin is logged in
    assert_text 'admin@test.com'

    # 2. Admin navigates to users page
    click_on 'admin@test.com' # Avatar dropdown
    click_on 'Users'
    
    # Verify we're on the users page
    assert_current_path '/users'
    assert_text 'Manage user accounts'

    # 3. Admin finds the regular user and starts impersonation
    assert_text 'Test User'
    
    # Look for the impersonation button (switch icon)
    within("tr", text: "Test User") do
      # Find the form with the impersonation button and submit it
      page.accept_confirm("Are you sure you want to impersonate Test User?") do
        click_on class: 'btn-ghost text-info' # The impersonation button
      end
    end

    # 4. Verify impersonation started
    assert_current_path '/'
    assert_text 'You are now impersonating Test User'
    
    # Verify the impersonation banner appears
    assert_selector '.bg-warning', text: 'You are impersonating Test User'
    assert_text 'Logged in as admin@test.com'

    # 5. Navigate around as the impersonated user
    # The current_user should now be the regular user
    # but the original admin should be available via current_impersonator

    # 6. Stop impersonation via banner
    within('.bg-warning') do
      page.accept_confirm("Are you sure you want to stop impersonating Test User?") do
        click_on 'Stop Impersonation'
      end
    end

    # 7. Verify impersonation ended
    assert_text 'Impersonation ended successfully'
    refute_selector '.bg-warning'
    
    # Should be back to admin user
    assert_text 'admin@test.com'
  end

  test "admin can view impersonation audit logs" do
    # Create test data
    admin = create(:user, :admin, email: 'admin@test.com', password: 'password123')
    regular_user = create(:user, email: 'user@test.com', first_name: 'Test', last_name: 'User')
    
    # Create some audit logs
    create(:impersonation_audit_log, 
           impersonator: admin,
           impersonated_user: regular_user,
           reason: 'Testing purposes',
           started_at: 1.hour.ago,
           ended_at: 30.minutes.ago)

    # Login as admin
    visit '/'
    click_on 'Sign In'
    fill_in 'Email', with: 'admin@test.com'
    fill_in 'Password', with: 'password123'
    click_on 'Log in'

    # Navigate to impersonation page
    click_on 'admin@test.com' # Avatar dropdown
    click_on 'Impersonation'

    # Verify audit logs are displayed
    assert_current_path '/admin/impersonation'
    assert_text 'User Impersonation'
    assert_text 'admin@test.com'
    assert_text 'Test User'
    assert_text 'Testing purposes'
    assert_text 'Ended'
  end

  test "regular user cannot access impersonation features" do
    # Create regular user
    regular_user = create(:user, email: 'user@test.com', password: 'password123')

    # Login as regular user
    visit '/'
    click_on 'Sign In'
    fill_in 'Email', with: 'user@test.com'
    fill_in 'Password', with: 'password123'
    click_on 'Log in'

    # Verify no impersonation links in navigation
    click_on 'user@test.com' # Avatar dropdown
    refute_text 'Impersonation'
    refute_text 'Users'

    # Try to access impersonation page directly
    visit '/admin/impersonation'
    
    # Should be redirected away (probably to root or login)
    refute_current_path '/admin/impersonation'
  end

  private

  def create(*args)
    FactoryBot.create(*args)
  end
end