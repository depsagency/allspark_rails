# allspark_rails - The AI-First Rails Template

[![Rails 8.0](https://img.shields.io/badge/Rails-8.0-red)](https://rubyonrails.org/)
[![Ruby 3.3](https://img.shields.io/badge/Ruby-3.3-red)](https://www.ruby-lang.org/)
[![MIT License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)

**Build production Rails apps in hours, not months. Perfect for vibe coding.**

Part of the AllSpark template family: **Rails** | [Django](https://github.com/allspark/allspark_django) | [Next.js](https://github.com/allspark/allspark_nextjs) | [More →](https://allspark.build/templates)

[Live Demo](https://demo.allspark.build) | [Documentation](docs/README.md) | [AllSpark Builder](https://creator.optimus.allspark.build)

## 🚀 Start Building in 60 Seconds

```bash
# One command to start
git clone https://github.com/TanookiLabs/allspark_rails.git my-app
cd my-app && ./setup.sh

# Or manually:
cp .env.example .env
docker-compose up -d
docker-compose exec web rails db:setup

# ✅ You're running! Visit http://localhost:3000
# Default login: admin@example.com / password123
```

## 🤖 Why Creators Choose allspark_rails

### For Solo Creators
- **10x faster development** with AI-optimized structure
- **Production-ready** from day one
- **No configuration** needed

### For Creative Teams
- **Consistent patterns** across all projects
- **Built-in best practices** from 12 years of agency work
- **Scalable architecture** that grows with you

### For AI-Powered Creators
- **Perfect for Claude, Cursor, Copilot**
- **Structured for AI understanding**
- **Rich context and documentation**

## ✨ What's Included

### 🎯 Core Features
- **🔐 Authentication & Authorization** - Devise + Pundit, user impersonation, JWT ready
- **🤖 AI Integration** - OpenRouter (100+ models), OpenAI, Claude, Gemini support
- **📝 App Project Builder** - AI generates PRDs and task lists from your requirements
- **💬 Real-time Chat** - ActionCable-powered with typing indicators and read receipts
- **📚 Knowledge Base** - RAG-enabled document management system
- **🔄 Visual Workflows** - Drag-and-drop workflow builder
- **⚡ Background Jobs** - Sidekiq with monitoring dashboard
- **🎨 Beautiful UI** - 30+ DaisyUI components, fully responsive

### 🛠 Developer Experience
- **Smart Generators** - `rails g ai_model`, `rails g ui_component`, `rails g service`
- **Self-Healing Tests** - Browser tests that diagnose and suggest fixes
- **Docker Development** - Zero-config development environment
- **AI-Optimized Docs** - CLAUDE.md with patterns and conventions
- **Quality Tools** - RuboCop, Brakeman, bundler-audit pre-configured

## 🔑 AI Configuration

### Option 1: OpenRouter (Recommended - One Key for Everything)
```bash
# Sign up at https://openrouter.ai
OPENROUTER_API_KEY=sk-or-v1-your-key-here
LLM_PROVIDER=openrouter
```
Access to GPT-4, Claude 3.5, Gemini, and 100+ more models with pay-per-use pricing.

### Option 2: Direct Provider Keys
```bash
# Choose your provider
LLM_PROVIDER=openai      # or 'anthropic' or 'gemini'

# Add corresponding key
OPENAI_API_KEY=sk-...    # For OpenAI/GPT models
ANTHROPIC_API_KEY=sk-ant-... # For Anthropic/Claude models  
GEMINI_API_KEY=...        # For Google/Gemini models
```

## 💻 AI Agent Quick Reference

All commands run inside Docker containers:

```bash
# Generate complete features
docker-compose exec web rails g scaffold Task title:string status:string
docker-compose exec web rails db:migrate

# Create UI components
docker-compose exec web rails g ui_component alert --variants=success,error,warning

# Add service objects  
docker-compose exec web rails g service payment_processor

# AI-enhanced models
docker-compose exec web rails g ai_model product --description="E-commerce product"

# View component library
# Visit http://localhost:3000/lookbook
```

## 📁 Project Structure

```
my-app/
├── .allspark/          # Template metadata and configuration
├── app/
│   ├── components/     # ViewComponents with DaisyUI
│   ├── services/       # Business logic services
│   └── channels/       # Real-time features
├── docs/
│   ├── getting-started/ # Installation and setup
│   ├── features/       # Feature documentation
│   └── guides/         # Development guides
└── CLAUDE.md          # AI assistant instructions
```

## 🚀 Deployment

### One-Click Deployment
- **Heroku**: Deploy button in repository
- **Railway**: Connect GitHub repo
- **Render**: Auto-deploy from GitHub

### Manual Deployment
```bash
# Docker (any VPS)
docker build -t myapp .
docker run -p 3000:3000 myapp

# DigitalOcean with Kamal
./deploy-to-digitalocean.sh
```

## 🎯 Who Are the Creators Using allspark_rails?

- **Indie Creators** building their next SaaS
- **Agency Creators** delivering client projects faster
- **Startup Creators** launching MVPs in days
- **Enterprise Creators** prototyping new ideas

## 📚 Documentation

- [Getting Started](docs/getting-started/installation.md) - Setup and installation
- [Features Guide](docs/features/README.md) - All features explained
- [AI Integration](docs/features/ai-integration.md) - LLM setup and usage
- [Deployment Guide](docs/guides/deployment.md) - Production deployment
- [CLAUDE.md](CLAUDE.md) - AI assistant instructions

## 🚀 Want More Power?

**AllSpark Builder** - Where creators build production apps

- Visual project planning
- One-click deployment  
- Team collaboration
- Enterprise features

[Start Building on AllSpark →](https://creator.optimus.allspark.build)

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

- 🐛 [Report bugs](https://github.com/TanookiLabs/allspark_rails/issues)
- 💡 [Request features](https://github.com/TanookiLabs/allspark_rails/discussions)
- 💬 [Join Discord](https://discord.gg/allspark)
- 🔧 PRs welcome!

## 📊 Stats

![GitHub stars](https://img.shields.io/github/stars/TanookiLabs/allspark_rails)
![GitHub forks](https://img.shields.io/github/forks/TanookiLabs/allspark_rails)
![Contributors](https://img.shields.io/github/contributors/TanookiLabs/allspark_rails)
![Last commit](https://img.shields.io/github/last-commit/TanookiLabs/allspark_rails)

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

---

**Built with ❤️ by creators, for creators**

Ready to build something amazing? Start with the [Quick Start](#-start-building-in-60-seconds) above or explore the [complete documentation](docs/README.md).