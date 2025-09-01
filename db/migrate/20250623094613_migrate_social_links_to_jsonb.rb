class MigrateSocialLinksToJsonb < ActiveRecord::Migration[8.0]
  def up
    # Add new JSONB column
    add_column :users, :social_links, :jsonb, default: {}
    add_index :users, :social_links, using: :gin

    # Migrate existing data
    User.find_each do |user|
      social_links = {}

      social_links['twitter'] = user.twitter_handle if user.twitter_handle.present?
      social_links['github'] = user.github_username if user.github_username.present?

      # Extract username from LinkedIn URL if it's a full URL
      if user.linkedin_url.present?
        if user.linkedin_url.include?('linkedin.com/in/')
          social_links['linkedin'] = user.linkedin_url.split('linkedin.com/in/').last.split('/').first
        else
          social_links['linkedin'] = user.linkedin_url
        end
      end

      user.update_column(:social_links, social_links) if social_links.any?
    end

    # Remove old columns
    remove_column :users, :twitter_handle
    remove_column :users, :github_username
    remove_column :users, :linkedin_url
  end

  def down
    # Add back old columns
    add_column :users, :twitter_handle, :string
    add_column :users, :github_username, :string
    add_column :users, :linkedin_url, :string

    # Migrate data back
    User.find_each do |user|
      next unless user.social_links.present?

      updates = {}
      updates[:twitter_handle] = user.social_links['twitter'] if user.social_links['twitter']
      updates[:github_username] = user.social_links['github'] if user.social_links['github']

      if user.social_links['linkedin']
        linkedin = user.social_links['linkedin']
        updates[:linkedin_url] = linkedin.include?('http') ? linkedin : "https://linkedin.com/in/#{linkedin}"
      end

      user.update_columns(updates) if updates.any?
    end

    # Remove JSONB column
    remove_index :users, :social_links
    remove_column :users, :social_links
  end
end
