# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::ThemeSwitcherComponent, type: :component do
  include_examples 'a view component'

  let(:component) { described_class.new }

  describe 'rendering' do
    it 'renders the component' do
      render_inline(component)

      expect(page).to have_css('.theme-switcher')
    end

    it 'includes theme controller data attributes' do
      render_inline(component)

      expect(page).to have_css('[data-controller="theme"]')
      expect(page).to have_css('[data-theme-default-value="light"]')
      expect(page).to have_css('[data-theme-storage-key-value="daisyui-theme"]')
    end
  end

  describe 'variants' do
    context 'when variant is dropdown' do
      let(:component) { described_class.new(variant: :dropdown) }

      it 'renders dropdown structure' do
        render_inline(component)

        expect(page).to have_css('.dropdown')
        expect(page).to have_css('[tabindex="0"]')
        expect(page).to have_css('.dropdown-content')
      end

      it 'includes theme options' do
        render_inline(component)

        expect(page).to have_css('[data-theme-option]')
        expect(page).to have_css('[data-action*="selectTheme"]')
      end
    end

    context 'when variant is toggle' do
      let(:component) { described_class.new(variant: :toggle) }

      it 'renders toggle structure' do
        render_inline(component)

        expect(page).to have_css('.swap')
        expect(page).to have_css('input[type="checkbox"]')
        expect(page).to have_css('[data-action*="toggle"]')
      end

      it 'includes sun and moon icons' do
        render_inline(component)

        expect(page).to have_css('.swap-off')
        expect(page).to have_css('.swap-on')
      end
    end

    context 'when variant is button_group' do
      let(:component) { described_class.new(variant: :button_group) }

      it 'renders button group structure' do
        render_inline(component)

        expect(page).to have_css('.btn-group')
        expect(page).to have_css('button.btn')
        expect(page).to have_css('[data-theme-value]')
      end
    end

    context 'when variant is compact' do
      let(:component) { described_class.new(variant: :compact) }

      it 'renders compact structure' do
        render_inline(component)

        expect(page).to have_css('.join')
        expect(page).to have_css('.join-item')
        expect(page).to have_css('[data-action*="cycle"]')
      end
    end
  end

  describe 'sizes' do
    %i[xs sm md lg].each do |size|
      context "when size is #{size}" do
        let(:component) { described_class.new(size: size) }

        it "includes the #{size} size classes" do
          render_inline(component)

          if size == :md
            # Medium is default, no specific class
            expect(page).to have_css('.theme-switcher')
          else
            expect(page).to have_css(".btn-#{size}")
          end
        end
      end
    end
  end

  describe 'options' do
    context 'when show_current is true' do
      let(:component) { described_class.new(show_current: true) }

      it 'includes theme indicator' do
        render_inline(component)

        expect(page).to have_css('[data-theme-target="indicator"]')
      end
    end

    context 'when show_current is false' do
      let(:component) { described_class.new(show_current: false) }

      it 'does not include theme indicator' do
        render_inline(component)

        expect(page).not_to have_css('[data-theme-target="indicator"]')
      end
    end

    context 'when show_icons is true' do
      let(:component) { described_class.new(show_icons: true) }

      it 'includes icons in theme options' do
        render_inline(component)

        # Should have some emoji or icon characters
        expect(page.text).to match(/[🌙☀️🎨💻]/)
      end
    end

    context 'when show_icons is false' do
      let(:component) { described_class.new(show_icons: false) }

      it 'does not include icons' do
        render_inline(component)

        # Should not have emoji characters in theme names
        expect(page.text).not_to match(/[🌙☀️🧁🐝💚🏢🌆📻🤖💝🎃🌸🌲🌊📼🎨🦄📐⚫💎🧛🖨️🍂💼🧪🍋🌃☕❄️🔅🏔️🌅]/)
      end
    end

    context 'when popular_only is true' do
      let(:component) { described_class.new(popular_only: true) }

      it 'shows only popular themes' do
        render_inline(component)

        # Should have fewer theme options
        theme_options = page.all('[data-theme-option]')
        expect(theme_options.length).to be <= 8
      end
    end

    context 'when popular_only is false' do
      let(:component) { described_class.new(popular_only: false) }

      it 'shows all available themes' do
        render_inline(component)

        # Should have more theme options
        theme_options = page.all('[data-theme-option]')
        expect(theme_options.length).to be > 8
      end
    end
  end

  describe 'positions' do
    %i[start end top bottom].each do |position|
      context "when position is #{position}" do
        let(:component) { described_class.new(position: position, variant: :dropdown) }

        it "includes the #{position} position class" do
          render_inline(component)

          expect(page).to have_css(".dropdown-#{position}")
        end
      end
    end
  end

  describe 'accessibility' do
    let(:component) { described_class.new(variant: :dropdown) }

    it 'includes proper ARIA attributes' do
      render_inline(component)

      expect(page).to have_css('[role="button"]')
      expect(page).to have_css('[tabindex="0"]')
    end

    context 'with toggle variant' do
      let(:component) { described_class.new(variant: :toggle) }

      it 'includes checkbox input for screen readers' do
        render_inline(component)

        expect(page).to have_css('input[type="checkbox"]')
      end
    end
  end

  describe 'stimulus integration' do
    it 'includes theme controller' do
      render_inline(component)

      expect(page).to have_css('[data-controller="theme"]')
    end

    it 'includes theme targets' do
      render_inline(component)

      expect(page).to have_css('[data-theme-target]')
    end

    it 'includes theme actions' do
      render_inline(component)

      expect(page).to have_css('[data-action*="theme#"]')
    end
  end

  describe 'custom classes' do
    let(:component) { described_class.new(class_names: 'custom-class') }

    it 'includes custom classes' do
      render_inline(component)

      expect(page).to have_css('.custom-class')
    end
  end
end
