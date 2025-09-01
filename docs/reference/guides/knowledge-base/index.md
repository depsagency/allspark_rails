# Knowledge Base Documentation

Welcome to the AllSpark Knowledge Base documentation. This comprehensive guide covers all aspects of using the enhanced knowledge management system with flexible tagging and metadata capabilities.

## Documentation Structure

### 📖 [User Guide](README.md)
Complete user documentation with screenshots covering:
- Browsing and searching documents
- Creating new documents with metadata
- Managing tags and custom attributes
- Using filters and advanced search
- Best practices and troubleshooting

### 🎨 [Visual Guide](visual-guide.md)
Detailed visual descriptions including:
- Page layouts and UI elements
- Interactive components and behaviors
- ASCII diagrams for interface structure
- Empty states and loading indicators

### 📸 [Screenshots](screenshots/)
Visual examples of the Knowledge Base interface:
- `01_knowledge_base_index.png` - Main knowledge base view
- `03_new_document_form.png` - Creating a new document
- `04_form_filled.png` - Example of filled form with metadata

## Key Features

### 🔍 Semantic Search
- AI-powered natural language search
- Understands context and meaning
- Finds relevant documents even without exact keyword matches

### 🏷️ Flexible Tagging System
- Multiple tags per document
- Tag normalization and suggestions
- Click tags to filter documents

### 📁 Organization
- Categories for broad classification
- Projects for team-based organization
- Visibility controls (Private, Team, Public)
- Priority levels (Low, Normal, High, Critical)

### ⚙️ Custom Metadata
- Add any key-value pairs
- Examples: version, author, last_reviewed
- Fully searchable via JSONB queries

### 🚀 Performance
- PostgreSQL JSONB with GIN indexes
- Efficient filtering and searching
- Automatic document chunking

## Quick Start

1. **Access the Knowledge Base**: Navigate to `/agents/knowledge_documents`
2. **Search**: Use the semantic search bar for natural language queries
3. **Create**: Click "Upload Document" to add new content
4. **Organize**: Use tags, categories, and custom metadata
5. **Filter**: Use the filters panel to narrow results

## Technical Implementation

The Knowledge Base uses:
- **Taggable Concern**: Reusable module for metadata management
- **JSONB Storage**: Flexible schema-less metadata
- **GIN Indexes**: Fast queries on JSONB data
- **pgvector**: Semantic search with embeddings
- **Advanced Search**: Combines AI search with metadata filters

For developers interested in the implementation, see:
- `/app/models/concerns/taggable.rb` - Metadata management concern
- `/app/models/knowledge_document.rb` - Enhanced with Taggable
- `/app/controllers/agents/knowledge_documents_controller.rb` - Filtering logic
- `/db/migrate/*_add_metadata_indexes_to_knowledge_documents.rb` - Database indexes

## Support

If you need help:
1. Check the [User Guide](README.md) for detailed instructions
2. Review the [Visual Guide](visual-guide.md) for UI descriptions
3. Contact your administrator for assistance
4. Submit feedback for improvements