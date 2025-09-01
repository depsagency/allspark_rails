# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UI::BadgeComponent, type: :component do
  include_examples 'a view component'

  let(:component) { described_class.new }

  describe 'rendering' do
    it 'renders the component' do
      render_inline(component)
      
      expect(page).to have_css('.badge')
    end

    it 'renders with default text' do
      render_inline(component)
      
      expect(page).to have_content('Badge')
    end
  end

  describe 'variants' do
        context 'when variant is success,warning,error' do
      let(:component) { described_class.new(variant: :success,warning,error) }

      it 'includes the success,warning,error variant class' do
        render_inline(component)
        
        expect(page).to have_css('.badge--success,warning,error')
      end
    end

      end

  describe 'sizes' do
    %i[xs sm md lg].each do |size|
      context "when size is #{size}" do
        let(:component) { described_class.new(size: size) }

        it "includes the #{size} size class" do
          render_inline(component)
          
          expect(page).to have_css(".badge--#{size}")
        end
      end
    end
  end

  describe 'states' do
    context 'when disabled' do
      let(:component) { described_class.new(disabled: true) }

      it 'includes the disabled state class' do
        render_inline(component)
        
        expect(page).to have_css('.badge--disabled')
      end

      it 'adds disabled attribute' do
        render_inline(component)
        
        expect(page).to have_css('[disabled]')
      end
    end

    context 'when not disabled' do
      let(:component) { described_class.new(disabled: false) }

      it 'does not include the disabled state class' do
        render_inline(component)
        
        expect(page).not_to have_css('.badge--disabled')
      end

      it 'does not add disabled attribute' do
        render_inline(component)
        
        expect(page).not_to have_css('[disabled]')
      end
    end
  end

  describe 'content' do
    context 'with text option' do
      let(:component) { described_class.new(text: 'Custom text') }

      it 'renders the custom text' do
        render_inline(component)
        
        expect(page).to have_content('Custom text')
      end
    end

    context 'with html_content option' do
      let(:component) { described_class.new(html_content: '<strong>Bold text</strong>') }

      it 'renders the HTML content' do
        render_inline(component)
        
        expect(page).to have_css('strong')
        expect(page).to have_content('Bold text')
      end
    end

    context 'with block content' do
      it 'renders the block content' do
        render_inline(component) { 'Block content' }
        
        expect(page).to have_content('Block content')
      end
    end
  end

  describe 'custom classes' do
    let(:component) { described_class.new(class_names: 'custom-class another-class') }

    it 'includes custom classes' do
      render_inline(component)
      
      expect(page).to have_css('.custom-class.another-class')
    end
  end

  describe 'data attributes' do
    let(:component) { described_class.new(data: { testid: 'my-component', value: '123' }) }

    it 'includes data attributes' do
      render_inline(component)
      
      expect(page).to have_css('[data-testid="my-component"]')
      expect(page).to have_css('[data-value="123"]')
    end
  end

    describe 'stimulus integration' do
    let(:component) { described_class.new }

    it 'includes stimulus controller data attribute' do
      render_inline(component)
      
      expect(page).to have_css('[data-controller="badge-component"]')
    end
  end
  
  describe 'accessibility' do
    let(:component) { described_class.new(text: 'Accessible Badge') }

    it 'has accessible content' do
      render_inline(component)
      
      expect(page).to have_content('Accessible Badge')
    end

    context 'when disabled' do
      let(:component) { described_class.new(disabled: true) }

      it 'is properly marked as disabled' do
        render_inline(component)
        
        expect(page).to have_css('[disabled]')
      end
    end
  end
end