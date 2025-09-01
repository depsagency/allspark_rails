# frozen_string_literal: true

# @label Card
class CardComponentPreview < Lookbook::Preview
  # @label Basic Card
  # @param title text "Card title"
  # @param compact toggle
  # @param bordered toggle
  def default(title: "Card Title", compact: false, bordered: false)
    render Ui::CardComponent.new(title: title, compact: compact, bordered: bordered) do
      "This is the card content. You can put any content here including text, images, buttons, and other components."
    end
  end

  # @label Card with Actions
  def with_actions
    render Ui::CardComponent.new(title: "User Profile", bordered: true) do |card|
      card.with_body do
        <<~HTML.html_safe
          <div class="space-y-4">
            <div class="flex items-center gap-4">
              <div class="avatar">
                <div class="w-16 rounded-full">
                  <img src="https://ui-avatars.com/api/?name=John+Doe&background=570df8&color=fff" alt="Avatar" />
                </div>
              </div>
              <div class="ml-2">
                <h3 class="font-semibold">John Doe</h3>
                <p class="text-sm opacity-70">john.doe@example.com</p>
              </div>
            </div>
          </div>
        HTML
      end

      card.with_actions do
        "Demo actions - View Profile, Edit"
      end
    end
  end

  # @label Compact Cards
  def compact_cards
    render Ui::CardComponent.new(title: "Active Users", compact: true, bordered: true) do
      <<~HTML.html_safe
        <div class="text-center">
          <div class="text-3xl font-bold text-primary">1,234</div>
          <div class="text-sm opacity-70 mt-1">↗︎ 12% from last month</div>
        </div>
      HTML
    end
  end

  # @label Card with Image
  def with_image
    render Ui::CardComponent.new(title: "Beautiful Sunset", bordered: true) do |card|
      card.with_image(
        src: "https://picsum.photos/400/200?random=1",
        alt: "Sunset"
      )

      card.with_body do
        "A beautiful sunset captured during our recent trip. The colors were absolutely magnificent and created a perfect moment for photography."
      end

      card.with_actions do
        "Like, Share, Download buttons would go here"
      end
    end
  end

  # @label Loading Card
  def loading_state
    render Ui::CardComponent.new(title: "Loading Content", bordered: true) do
      <<~HTML.html_safe
        <div class="space-y-4">
          <div class="skeleton h-4 w-full"></div>
          <div class="skeleton h-4 w-3/4"></div>
          <div class="skeleton h-4 w-1/2"></div>
          <div class="skeleton h-20 w-full"></div>
        </div>
      HTML
    end
  end

  # @label Card Layouts
  def different_layouts
    render Ui::CardComponent.new(title: "Product Showcase", side: true, bordered: true) do |card|
      card.with_image(
        src: "https://picsum.photos/300/200?random=2",
        alt: "Product"
      )

      card.with_body do
        "This is a horizontal card layout that works great for product displays or feature highlights."
      end

      card.with_actions do
        "Learn More button would go here"
      end
    end
  end
end
