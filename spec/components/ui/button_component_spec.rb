# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::ButtonComponent, type: :component do
  include_examples 'a component'

  let(:component_kwargs) { {} }

  describe 'rendering' do
    it 'renders a button element' do
      component = described_class.new
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn')
    end

    it 'renders with default classes' do
      component = described_class.new
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn.btn-primary')
    end

    it 'renders with custom text' do
      component = described_class.new(text: 'Click me')
      html = render_inline(component).to_html

      expect(html).to have_content('Click me')
    end

    it 'renders with block content' do
      component = described_class.new
      html = render_inline(component) { 'Block content' }.to_html

      expect(html).to have_content('Block content')
    end
  end

  describe 'variants' do
    %w[primary secondary accent ghost link].each do |variant|
      it "renders #{variant} variant" do
        component = described_class.new(variant: variant)
        html = render_inline(component).to_html

        expect(html).to have_css("button.btn-#{variant}")
      end
    end

    it 'falls back to primary for invalid variant' do
      component = described_class.new(variant: 'invalid')
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn-primary')
    end
  end

  describe 'sizes' do
    %w[xs sm md lg].each do |size|
      it "renders #{size} size" do
        component = described_class.new(size: size)
        html = render_inline(component).to_html

        if size == 'md'
          expect(html).not_to have_css('button.btn-md') # Default size
        else
          expect(html).to have_css("button.btn-#{size}")
        end
      end
    end
  end

  describe 'states' do
    it 'renders loading state' do
      component = described_class.new(loading: true)
      html = render_inline(component).to_html

      expect(html).to have_css('button.loading')
    end

    it 'renders disabled state' do
      component = described_class.new(disabled: true)
      html = render_inline(component).to_html

      expect(html).to have_css('button[disabled]')
    end

    it 'renders active state' do
      component = described_class.new(active: true)
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn-active')
    end
  end

  describe 'shapes' do
    %w[wide block circle square].each do |shape|
      it "renders #{shape} shape" do
        component = described_class.new(shape: shape)
        html = render_inline(component).to_html

        expect(html).to have_css("button.btn-#{shape}")
      end
    end
  end

  describe 'outline' do
    it 'renders outline style' do
      component = described_class.new(outline: true)
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn-outline')
    end
  end

  describe 'link rendering' do
    it 'renders as link when url is provided' do
      component = described_class.new(url: '/test')
      html = render_inline(component).to_html

      expect(html).to have_css('a.btn[href="/test"]')
    end

    it 'applies link-specific attributes' do
      component = described_class.new(
        url: '/test',
        target: '_blank',
        method: :post
      )
      html = render_inline(component).to_html

      expect(html).to have_css('a[target="_blank"]')
      expect(html).to have_css('a[data-method="post"]')
    end
  end

  describe 'data attributes' do
    it 'includes custom data attributes' do
      component = described_class.new(
        data: {
          action: 'click->modal#open',
          target: 'modal.trigger'
        }
      )
      html = render_inline(component).to_html

      expect(html).to have_css('button[data-action="click->modal#open"]')
      expect(html).to have_css('button[data-target="modal.trigger"]')
    end
  end

  describe 'icons' do
    it 'renders with left icon' do
      component = described_class.new(
        text: 'Save',
        icon_left: '<svg>icon</svg>'.html_safe
      )
      html = render_inline(component).to_html

      expect(html).to have_css('svg')
      expect(html).to have_content('Save')
    end

    it 'renders with right icon' do
      component = described_class.new(
        text: 'Next',
        icon_right: '<svg>icon</svg>'.html_safe
      )
      html = render_inline(component).to_html

      expect(html).to have_css('svg')
      expect(html).to have_content('Next')
    end

    it 'renders icon-only button' do
      component = described_class.new(
        icon_left: '<svg>icon</svg>'.html_safe,
        shape: 'circle'
      )
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn-circle')
      expect(html).to have_css('svg')
    end
  end

  describe 'accessibility' do
    it 'includes aria-label when provided' do
      component = described_class.new(aria_label: 'Close dialog')
      html = render_inline(component).to_html

      expect(html).to have_css('button[aria-label="Close dialog"]')
    end

    it 'includes aria-disabled for disabled buttons' do
      component = described_class.new(disabled: true)
      html = render_inline(component).to_html

      expect(html).to have_css('button[aria-disabled="true"]')
    end

    it 'includes aria-pressed for active toggle buttons' do
      component = described_class.new(
        active: true,
        data: { toggle: true }
      )
      html = render_inline(component).to_html

      expect(html).to have_css('button[aria-pressed="true"]')
    end
  end

  describe 'custom classes' do
    it 'merges custom CSS classes' do
      component = described_class.new(css_class: 'custom-class')
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn.btn-primary.custom-class')
    end
  end

  describe 'validation' do
    it 'validates button type' do
      component = described_class.new(type: 'submit')
      html = render_inline(component).to_html

      expect(html).to have_css('button[type="submit"]')
    end

    it 'defaults to button type' do
      component = described_class.new
      html = render_inline(component).to_html

      expect(html).to have_css('button[type="button"]')
    end
  end

  describe 'form integration' do
    it 'renders with form attribute' do
      component = described_class.new(form: 'my-form')
      html = render_inline(component).to_html

      expect(html).to have_css('button[form="my-form"]')
    end

    it 'renders with formaction for submit buttons' do
      component = described_class.new(
        type: 'submit',
        formaction: '/alternative-action'
      )
      html = render_inline(component).to_html

      expect(html).to have_css('button[formaction="/alternative-action"]')
    end
  end

  describe 'responsive behavior' do
    it 'adds responsive classes when specified' do
      component = described_class.new(
        responsive: true,
        size: 'sm'
      )
      html = render_inline(component).to_html

      expect(html).to have_css('button.btn-sm')
    end
  end
end
