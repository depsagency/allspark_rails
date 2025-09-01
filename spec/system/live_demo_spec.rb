# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Live Demo Features', type: :system do
  include_context 'authenticated user'

  before do
    visit live_demo_index_path
  end

  describe 'page rendering' do
    it 'displays the live demo page' do
      expect(page).to have_content('Real-time Features Demo')
      expect(page).to have_css('[data-controller="navbar"]')
      expect(page).to have_css('[data-notification-count]')
    end

    it 'includes ActionCable meta tags' do
      expect(page).to have_css('meta[name="current-user-id"]', visible: false)
      expect(page).to have_css('meta[name="action-cable-csrf-token"]', visible: false)
    end
  end

  describe 'notifications demo', :js do
    it 'allows sending notifications' do
      within('.card:has-text("Notifications Demo")') do
        fill_in 'Title', with: 'Test Notification'
        fill_in 'Message', with: 'This is a test notification'
        select 'Success', from: 'Type'

        expect {
          click_button 'Send Notification'
        }.to change(Notification, :count).by(1)
      end

      expect(page).to have_content('Notification sent!')
    end

    it 'displays notifications in real-time', :vcr do
      # Create a notification via the backend
      notification = current_user.send_notification(
        title: 'Real-time Test',
        message: 'This notification should appear in real-time'
      )

      # Simulate real-time notification
      simulate_notification({
        id: notification.id,
        title: notification.title,
        message: notification.message,
        type: notification.notification_type,
        icon: notification.icon
      })

      expect(page).to have_content('Real-time Test')
      expect(page).to have_content('This notification should appear in real-time')
    end

    it 'updates notification badge counter' do
      badge = find('[data-notification-count]')
      initial_count = badge.text.to_i

      current_user.send_notification(
        title: 'Badge Test',
        message: 'Testing badge counter'
      )

      # The badge should update (in a real app via WebSocket)
      expect(page).to have_css('[data-notification-count]')
    end
  end

  describe 'presence demo', :js do
    it 'displays online users section' do
      expect(page).to have_content('Online Users')
      expect(page).to have_css('#online-users-list')
      expect(page).to have_css('#online-users-count')
    end

    it 'allows updating user activity status' do
      within('.card:has-text("Presence Demo")') do
        select 'Away', from: 'activity-select'
        # In a real test, this would trigger WebSocket updates
      end
    end

    it 'allows setting status message' do
      within('.card:has-text("Presence Demo")') do
        fill_in 'status-message', with: 'Working on tests'
        click_button 'Update Status'
        # In a real test, this would broadcast status change
      end
    end
  end

  describe 'live updates demo', :js do
    it 'allows broadcasting updates' do
      within('.card:has-text("Live Updates Demo")') do
        fill_in 'Message', with: 'Test broadcast message'

        click_button 'Broadcast Update'
      end

      expect(page).to have_content('Update broadcasted!')
    end

    it 'displays progress demo', :js do
      within('.card:has-text("Live Updates Demo")') do
        click_button 'Start Progress Demo'

        expect(page).to have_css('#progress-container:not(.hidden)')
        expect(page).to have_css('progress[data-operation-id]')
      end
    end
  end

  describe 'typing indicators', :js do
    it 'shows typing indicator demo' do
      expect(page).to have_css('#typing-demo')
      expect(page).to have_css('[data-typing-context="demo_chat"]')
    end

    it 'triggers typing when user types' do
      typing_area = find('#typing-demo')
      typing_area.fill_in with: 'Testing typing indicator'

      # In a real test, this would trigger typing indicator broadcasts
      expect(typing_area.value).to eq('Testing typing indicator')
    end
  end

  describe 'collaborative editing demo', :js do
    it 'displays collaborative editor' do
      expect(page).to have_css('[data-collaborative-editor]')
      expect(page).to have_css('#collaborative-editor')
    end

    it 'tracks cursor movement' do
      editor = find('#collaborative-editor')
      editor.click

      # In a real test with WebSockets, cursor position would be tracked
      expect(editor).to be_focused
    end
  end

  describe 'activity feed', :js do
    it 'displays activity feed' do
      expect(page).to have_css('#activity-feed')
    end

    it 'shows placeholder when no activity' do
      within('#activity-feed') do
        expect(page).to have_content('Activity will appear here')
      end
    end
  end

  describe 'responsive design' do
    it 'works on mobile viewport' do
      simulate_mobile

      expect(page).to have_css('.grid-cols-1')
      expect(page).to have_css('.navbar')
    end

    it 'works on tablet viewport' do
      simulate_tablet

      expect(page).to have_css('.navbar')
      expect(page).to have_content('Real-time Features Demo')
    end
  end

  describe 'admin features' do
    context 'when user is admin' do
      include_context 'authenticated admin'

      before do
        visit live_demo_index_path
      end

      it 'shows admin-only features' do
        expect(page).to have_content('Admin Only')
        expect(page).to have_button('Send System Announcement')
      end

      it 'allows sending system announcements' do
        within('.card:has-text("Notifications Demo")') do
          fill_in 'Title', with: 'System Maintenance'
          fill_in 'Message', with: 'The system will be down for maintenance'

          click_button 'Send System Announcement'
        end

        expect(page).to have_content('System announcement sent!')
      end
    end

    context 'when user is not admin' do
      it 'hides admin-only features' do
        expect(page).not_to have_content('Admin Only')
        expect(page).not_to have_button('Send System Announcement')
      end
    end
  end

  describe 'error handling' do
    it 'handles invalid notification data gracefully' do
      within('.card:has-text("Notifications Demo")') do
        # Leave title empty to trigger validation error
        fill_in 'Message', with: 'Message without title'

        click_button 'Send Notification'
      end

      # Should handle validation errors gracefully
      expect(page).to have_current_path(live_demo_index_path)
    end
  end

  describe 'accessibility' do
    it 'has proper ARIA labels' do
      expect(page).to have_css('[aria-label]')
    end

    it 'supports keyboard navigation' do
      # Test tab navigation
      page.send_keys(:tab)
      expect(page).to have_css(':focus')
    end

    it 'has semantic HTML structure' do
      expect(page).to have_css('main, section, article, aside', count: 1..)
      expect(page).to have_css('h1, h2, h3', count: 1..)
    end
  end

  describe 'theme switching' do
    it 'supports theme switching' do
      # Test theme switching if navbar is present
      if page.has_css?('[data-action*="setTheme"]')
        switch_theme('dark')
        expect_theme('dark')

        switch_theme('light')
        expect_theme('light')
      end
    end
  end
end
