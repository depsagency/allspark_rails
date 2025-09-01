# Knowledge Base Visual Guide

This guide provides detailed descriptions of the Knowledge Base interface and its features.

## Knowledge Base Index Page

### Page Layout

The Knowledge Base index page consists of several key sections:

```
┌─────────────────────────────────────────────────────────────┐
│  AllSpark  [Assistants] [Knowledge Base] [Settings] [Logout] │ 
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Knowledge Base                     [Upload Document] [Test]  │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 🔍 Search documents using semantic AI search...      │    │
│  │                                         [Search]     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─ Filters ─────────────────────────────────────────┐      │
│  │ ▼ Filters                                   3 active │     │
│  │                                                      │     │
│  │ Tags: [api] [security] [documentation] [mobile]...  │     │
│  │       □ Match all                                   │     │
│  │                                                      │     │
│  │ Category: [All Categories ▼]                        │     │
│  │ Project:  [All Projects ▼]                          │     │
│  │ Visibility: [All ▼]                                 │     │
│  │                                                      │     │
│  │ [Apply Filters] [Clear All]                         │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  ┌─ Statistics ──────────────────────────────────────┐       │
│  │  📄 Total Documents: 325  │  🧩 Chunks: 410       │       │
│  │  📚 Document Types: 5     │                       │       │
│  └──────────────────────────────────────────────────┘       │
│                                                               │
│  ┌─ Documents ──────────────────────────────────────────┐    │
│  │ Title           Type    Assistant  Chunks  Created   │    │
│  │ ─────────────────────────────────────────────────── │    │
│  │ REST API Guide  📖Docs  Global     5       Jan 14   │    │
│  │ [api][rest][v2]                                     │    │
│  │                                                      │    │
│  │ Security Guide  📖Docs  Team       3       Jan 13   │    │
│  │ [security][best-practices]                          │    │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Key Elements

1. **Navigation Bar**: Access to main AllSpark features
2. **Page Title**: "Knowledge Base" with action buttons
3. **Search Bar**: Natural language search input
4. **Filters Panel**: Collapsible panel with filtering options
5. **Statistics**: Overview of document counts
6. **Document Table**: List of all documents with metadata

## Search Interface

### Semantic Search Bar

The search interface features:
- Large, prominent search input field
- Placeholder text: "Search documents using semantic AI search (RAG)..."
- Search button on the right
- Clear button (X) appears when search is active

### Search Results

When searching, the page updates to show:
- Matching documents sorted by relevance
- Search query highlighted in context
- All filters remain available
- Original statistics update to show filtered counts

## Filters Panel

### Expanded View

When clicked, the Filters panel expands to show:

#### Tags Section
```
Tags:  [api] [security] [documentation] [mobile] [react] 
       [database] [authentication] [tutorial] [guide]
       □ Match all
```
- Tags appear as clickable badges
- Selected tags have primary color
- Unselected tags are outlined
- "Match all" checkbox changes AND/OR logic

#### Dropdown Filters
```
Category:   [All Categories        ▼]
            ├─ API Documentation
            ├─ User Guides
            ├─ Technical Documentation
            └─ Security Documentation

Project:    [All Projects          ▼]
            ├─ Mobile App v2
            ├─ Backend Services
            ├─ Web Application
            └─ Developer Portal

Visibility: [All                   ▼]
            ├─ Public
            ├─ Private
            ├─ Team
            └─ Restricted
```

## New Document Form

### Form Layout

```
┌─────────────────────────────────────────────────────────┐
│  Upload Document                              [← Back]   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Document Title *                                        │
│  ┌────────────────────────────────────────────────┐    │
│  │ API Authentication Guide                        │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  Assistant                                               │
│  [Global (All Assistants)                      ▼]       │
│                                                          │
│  ─── Document Source ───────────────────────────────    │
│                                                          │
│  Upload File                                             │
│  ┌────────────────────────────────────────────────┐    │
│  │ 📎 Choose file...              No file chosen  │    │
│  └────────────────────────────────────────────────┘    │
│  Supported: TXT, MD, PDF, DOCX, HTML                    │
│                                                          │
│  ─── OR ────────────────────────────────────────────    │
│                                                          │
│  Paste Content Directly                                  │
│  ┌────────────────────────────────────────────────┐    │
│  │                                                 │    │
│  │  Your content here...                           │    │
│  │                                                 │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  Source Type              Source URL                    │
│  [Documentation    ▼]     [https://example.com    ]    │
│                                                          │
│  ─── Organization & Tags ───────────────────────────    │
│                                                          │
│  Tags (comma-separated)                                 │
│  ┌────────────────────────────────────────────────┐    │
│  │ api, authentication, oauth2, security           │    │
│  └────────────────────────────────────────────────┘    │
│  Suggested: [+oauth] [+token] [+rest]                  │
│                                                          │
│  Category                 Project                        │
│  [API Documentation  ]    [Backend Services      ]      │
│                                                          │
│  Visibility               Priority                      │
│  [Team ▼]                 [High ▼]                      │
│                                                          │
│  Custom Attributes                                       │
│  ┌─────────────────┬─────────────────┬───┐            │
│  │ version         │ 2.0             │ X │            │
│  ├─────────────────┼─────────────────┼───┤            │
│  │ author          │ API Team        │ X │            │
│  └─────────────────┴─────────────────┴───┘            │
│  [+ Add Custom Attribute]                               │
│                                                          │
│  [Upload Document]                                       │
└─────────────────────────────────────────────────────────┘
```

### Form Features

1. **Title Field**: Required, with descriptive placeholder
2. **Assistant Selector**: Global or specific assistant
3. **File Upload**: Drag-and-drop or click to browse
4. **Content Editor**: Large textarea for direct input
5. **Metadata Fields**: All optional but recommended
6. **Tag Suggestions**: Based on content analysis
7. **Custom Attributes**: Dynamic key-value pairs

## Document View Page

### Page Structure

```
┌─────────────────────────────────────────────────────────┐
│  REST API Authentication Guide          [← Back] [Edit]  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─ Document Info ──────────────────────────────────┐   │
│  │ Created: Jan 14, 2025                            │   │
│  │ Author: demo@example.com                         │   │
│  │ Source: Documentation                            │   │
│  │ Processing: ✓ 5 chunks                          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─ Organization & Tags ────────────────────────────┐   │
│  │ Tags: [api] [authentication] [oauth2] [security] │   │
│  │                                                   │   │
│  │ Category: API Documentation                      │   │
│  │ Project: Backend Services                        │   │
│  │                                                   │   │
│  │ Visibility: [Team]    Priority: [High]          │   │
│  │                                                   │   │
│  │ Custom Attributes:                               │   │
│  │   version: 2.0                                   │   │
│  │   author: API Team                               │   │
│  │   last_reviewed: 2025-01-14                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─ Content ────────────────────────────────────────┐   │
│  │                                                   │   │
│  │ This guide covers OAuth 2.0 implementation...    │   │
│  │                                                   │   │
│  │ ## Table of Contents                             │   │
│  │ 1. Introduction                                  │   │
│  │ 2. OAuth 2.0 Flow                               │   │
│  │ 3. Implementation                                │   │
│  │                                                   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### View Features

1. **Header**: Title with navigation and edit button
2. **Document Info**: Metadata and processing status
3. **Organization & Tags**: Clickable elements for filtering
4. **Content**: Rendered markdown with syntax highlighting

## Edit Document Page

The edit page mirrors the new document form but with:
- Pre-filled values
- "Update Document" button instead of "Upload"
- Option to replace uploaded files
- All metadata fields editable

## Visual Indicators

### Badges and Tags

- **Document Type Badges**:
  - 📖 Docs (green) - Documentation
  - 💻 Code (blue) - Code samples
  - 📚 General (gray) - Untyped content

- **Priority Badges**:
  - 🔴 Critical - Red badge
  - 🟡 High - Yellow/warning badge
  - 🔵 Normal - Blue/info badge
  - ⚪ Low - Gray/ghost badge

- **Visibility Badges**:
  - 🟢 Public - Green/success
  - 🔵 Team - Blue/info
  - 🟡 Private - Yellow/warning
  - 🔴 Restricted - Red/error

### Status Indicators

- **Processing Status**:
  - ⏳ Processing... - Yellow badge
  - ✅ 5 chunks - Number of processed chunks
  - ❌ Failed - Error state

- **File Indicators**:
  - 📎 Has attachment
  - 📄 Text only

## Interactive Elements

### Hover States

- Document titles: Underline on hover
- Tags: Slight color change and cursor pointer
- Buttons: Opacity change
- Table rows: Background highlight

### Click Actions

- **Tags**: Filter knowledge base by that tag
- **Category/Project**: Filter by that category/project
- **Document Title**: Navigate to document view
- **Edit Button**: Open edit form
- **Visibility/Priority**: No action (display only)

## Responsive Design

The Knowledge Base adapts to different screen sizes:

### Desktop (1200px+)
- Full table view with all columns
- Side-by-side form fields
- Expanded filters panel by default

### Tablet (768px-1199px)
- Condensed table (some columns hidden)
- Stacked form fields
- Filters panel collapsed by default

### Mobile (<768px)
- Card-based document list
- Single column forms
- Simplified filters
- Touch-optimized controls

## Empty States

### No Documents
```
┌─────────────────────────────────────────────┐
│                                             │
│            📚                               │
│                                             │
│        No documents yet                     │
│                                             │
│   Start building your knowledge base        │
│                                             │
│        [Upload First Document]              │
│                                             │
└─────────────────────────────────────────────┘
```

### No Search Results
```
┌─────────────────────────────────────────────┐
│                                             │
│            🔍                               │
│                                             │
│     No documents match your search          │
│                                             │
│   Try different keywords or filters         │
│                                             │
│         [Clear Search]                      │
│                                             │
└─────────────────────────────────────────────┘
```

## Loading States

- **Search**: "Searching..." with spinner
- **Upload**: Progress bar for large files
- **Processing**: "Processing document..." message
- **Filters**: Brief loading overlay when applying

This visual guide provides a comprehensive overview of the Knowledge Base interface, helping users understand and navigate all features effectively.