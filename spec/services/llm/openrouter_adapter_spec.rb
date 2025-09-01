require 'rails_helper'

RSpec.describe Llm::OpenrouterAdapter do
  let(:api_key) { "sk-or-v1-test-key" }
  let(:adapter) { described_class.new(api_key: api_key) }

  describe "#initialize" do
    it "normalizes model names from direct provider format" do
      adapter = described_class.new(api_key: api_key, model: "gpt-4o-mini")
      expect(adapter.model_name).to eq("openai/gpt-4o-mini")
    end

    it "keeps OpenRouter format models as-is" do
      adapter = described_class.new(api_key: api_key, model: "anthropic/claude-3.5-sonnet")
      expect(adapter.model_name).to eq("anthropic/claude-3.5-sonnet")
    end

    it "defaults to openai/gpt-4o-mini" do
      expect(adapter.model_name).to eq("openai/gpt-4o-mini")
    end

    it "handles unknown models by prefixing with openai/" do
      adapter = described_class.new(api_key: api_key, model: "unknown-model")
      expect(adapter.model_name).to eq("openai/unknown-model")
    end
  end

  describe "#available?" do
    context "without API key" do
      let(:adapter) { described_class.new(api_key: nil) }

      it "returns false" do
        expect(adapter).not_to be_available
      end
    end

    context "with API key" do
      it "checks API availability by calling models endpoint" do
        stub_request(:get, "https://openrouter.ai/api/v1/models")
          .with(
            headers: {
              'Authorization' => "Bearer #{api_key}",
              'Content-Type' => 'application/json',
              'HTTP-Referer' => 'http://localhost:3000',
              'X-Title' => 'Allspark Rails App'
            }
          )
          .to_return(status: 200, body: { data: [] }.to_json)

        expect(adapter).to be_available
      end

      it "returns false on API error" do
        stub_request(:get, "https://openrouter.ai/api/v1/models")
          .to_return(status: 401)

        expect(adapter).not_to be_available
      end
    end
  end

  describe "#generate" do
    let(:prompt) { "Hello, world!" }
    let(:response_body) do
      {
        choices: [
          {
            message: {
              content: "Hi there!"
            }
          }
        ]
      }
    end

    before do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .with(
          body: {
            model: "openai/gpt-4o-mini",
            messages: [ { role: "user", content: prompt } ],
            max_tokens: 1000,
            temperature: 0.7
          }.to_json,
          headers: {
            'Authorization' => "Bearer #{api_key}",
            'Content-Type' => 'application/json',
            'HTTP-Referer' => 'http://localhost:3000',
            'X-Title' => 'Allspark Rails App'
          }
        )
        .to_return(status: 200, body: response_body.to_json)
    end

    it "sends request to OpenRouter API" do
      response = adapter.generate(prompt)
      expect(response).to eq("Hi there!")
    end

    it "supports custom options" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .with(
          body: hash_including(
            max_tokens: 500,
            temperature: 0.3
          )
        )
        .to_return(status: 200, body: response_body.to_json)

      adapter.generate(prompt, max_tokens: 500, temperature: 0.3)
    end
  end

  describe "#chat" do
    let(:messages) do
      [
        { role: "user", content: "Hello" },
        { role: "assistant", content: "Hi!" },
        { role: "user", content: "How are you?" }
      ]
    end

    it "sends chat messages to OpenRouter" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .with(body: hash_including(messages: messages))
        .to_return(
          status: 200,
          body: {
            choices: [ { message: { content: "I'm doing well!" } } ]
          }.to_json
        )

      response = adapter.chat(messages)
      expect(response).to eq("I'm doing well!")
    end
  end

  describe "error handling" do
    let(:prompt) { "Test prompt" }

    it "raises AuthenticationError for 401 responses" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          status: 401,
          body: { error: { message: "Invalid API key" } }.to_json
        )

      expect { adapter.generate(prompt) }
        .to raise_error(Llm::AuthenticationError, /Invalid API key/)
    end

    it "raises PaymentRequiredError for 402 responses" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          status: 402,
          body: { error: { message: "Insufficient credits" } }.to_json
        )

      expect { adapter.generate(prompt) }
        .to raise_error(Llm::PaymentRequiredError, /Insufficient credits/)
    end

    it "raises RateLimitError for 429 responses" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          status: 429,
          body: { error: { message: "Rate limit exceeded" } }.to_json
        )

      expect { adapter.generate(prompt) }
        .to raise_error(Llm::RateLimitError, /Rate limit exceeded/)
    end

    it "raises ServiceError for 5xx responses" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          status: 500,
          body: { error: { message: "Internal server error" } }.to_json
        )

      expect { adapter.generate(prompt) }
        .to raise_error(Llm::ServiceError, /Internal server error/)
    end
  end

  describe "model mappings" do
    [
      [ "gpt-4o-mini", "openai/gpt-4o-mini" ],
      [ "gpt-4o", "openai/gpt-4o" ],
      [ "claude-3-5-sonnet-20241022", "anthropic/claude-3.5-sonnet" ],
      [ "gemini-1.5-flash", "google/gemini-flash-1.5" ],
      [ "gemini-2.0-flash", "google/gemini-flash-2.0" ]
    ].each do |input_model, expected_model|
      it "maps #{input_model} to #{expected_model}" do
        adapter = described_class.new(api_key: api_key, model: input_model)
        expect(adapter.model_name).to eq(expected_model)
      end
    end
  end
end
