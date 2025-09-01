# frozen_string_literal: true

namespace :knowledge_base do
  desc "Import all documents from /docs directory into the knowledge base"
  task import_docs: :environment do
    puts "🚀 Starting knowledge base import from /docs directory..."
    
    # Find or create a system user for these documents
    system_user = User.find_or_create_by!(email: 'system@allspark.ai') do |u|
      u.password = SecureRandom.hex(32)
      u.first_name = 'System'
      u.last_name = 'Import'
    end
    
    docs_path = Rails.root.join('docs')
    unless Dir.exist?(docs_path)
      puts "❌ Error: /docs directory not found at #{docs_path}"
      exit 1
    end
    
    imported_count = 0
    skipped_count = 0
    error_count = 0
    
    # Find all markdown and text files recursively
    files = Dir.glob(File.join(docs_path, '**', '*.{md,txt,markdown}'))
    
    if files.empty?
      puts "⚠️  No markdown or text files found in #{docs_path}"
      exit 0
    end
    
    puts "📄 Found #{files.length} files to process"
    puts "-" * 50
    
    files.each_with_index do |file_path, index|
      relative_path = Pathname.new(file_path).relative_path_from(docs_path).to_s
      
      # Check if document already exists
      existing_doc = KnowledgeDocument.find_by(
        source_url: "file://docs/#{relative_path}",
        user: system_user
      )
      
      if existing_doc
        puts "⏭️  [#{index + 1}/#{files.length}] Skipping (already imported): #{relative_path}"
        skipped_count += 1
        next
      end
      
      begin
        print "📥 [#{index + 1}/#{files.length}] Importing: #{relative_path}..."
        
        # Read file content
        content = File.read(file_path)
        
        # Extract title from filename or first heading
        title = extract_title(file_path, content)
        
        # Create knowledge document
        doc = KnowledgeDocument.create!(
          user: system_user,
          title: title,
          content: content,
          source_type: 'documentation',
          source_url: "file://docs/#{relative_path}",
          metadata: {
            imported_at: Time.current.iso8601,
            file_path: relative_path,
            file_size: File.size(file_path),
            importer_version: '1.0'
          }
        )
        
        # Process the document to create chunks and embeddings
        doc.process!
        
        puts " ✅ (#{doc.knowledge_chunks.count} chunks)"
        imported_count += 1
        
      rescue => e
        puts " ❌ Error: #{e.message}"
        error_count += 1
        Rails.logger.error "Failed to import #{file_path}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    
    puts "-" * 50
    puts "\n📊 Import Summary:"
    puts "   ✅ Imported: #{imported_count} documents"
    puts "   ⏭️  Skipped: #{skipped_count} documents (already imported)"
    puts "   ❌ Errors: #{error_count} documents" if error_count > 0
    puts "\n✨ Knowledge base import completed!"
  end
  
  desc "Clear all system-imported documents from the knowledge base"
  task clear_imported_docs: :environment do
    puts "🗑️  Clearing system-imported documents..."
    
    system_user = User.find_by(email: 'system@allspark.ai')
    if system_user
      count = system_user.knowledge_documents.where(source_type: 'documentation').count
      
      if count > 0
        print "⚠️  This will delete #{count} documents. Are you sure? (y/N): "
        response = STDIN.gets.chomp.downcase
        
        if response == 'y'
          system_user.knowledge_documents.where(source_type: 'documentation').destroy_all
          puts "✅ Deleted #{count} documents"
        else
          puts "❌ Cancelled"
        end
      else
        puts "ℹ️  No system-imported documents found"
      end
    else
      puts "ℹ️  No system user found"
    end
  end
  
  desc "Show statistics about the knowledge base"
  task stats: :environment do
    puts "\n📊 Knowledge Base Statistics"
    puts "=" * 50
    
    total_docs = KnowledgeDocument.count
    total_chunks = KnowledgeChunk.count
    
    puts "📄 Total Documents: #{total_docs}"
    puts "🧩 Total Chunks: #{total_chunks}"
    puts "📏 Average Chunks per Document: #{total_docs > 0 ? (total_chunks.to_f / total_docs).round(2) : 0}"
    
    # Documents by source type
    puts "\n📁 Documents by Source Type:"
    KnowledgeDocument.group(:source_type).count.each do |source_type, count|
      puts "   #{source_type || 'manual'}: #{count}"
    end
    
    # Documents by user
    puts "\n👤 Documents by User:"
    User.joins(:knowledge_documents)
        .group('users.email')
        .count
        .sort_by { |_, count| -count }
        .first(10)
        .each do |email, count|
      puts "   #{email}: #{count}"
    end
    
    # System imported docs
    system_user = User.find_by(email: 'system@allspark.ai')
    if system_user
      system_docs = system_user.knowledge_documents.where(source_type: 'documentation').count
      puts "\n🤖 System Imported Docs: #{system_docs}"
    end
    
    # Recent documents
    puts "\n🕐 Recent Documents (last 5):"
    KnowledgeDocument.order(created_at: :desc).limit(5).each do |doc|
      puts "   - #{doc.title} (#{doc.created_at.strftime('%Y-%m-%d %H:%M')})"
    end
    
    puts "\n✅ Done!"
  end
  
  desc "Index application codebase into the knowledge base"
  task index_codebase: :environment do
    puts "🚀 Starting codebase indexing..."
    
    # Find or create a system user for code documents
    system_user = User.find_or_create_by!(email: 'system@allspark.ai') do |u|
      u.password = SecureRandom.hex(32)
      u.first_name = 'System'
      u.last_name = 'Import'
    end
    
    # Define directories to scan and files to exclude
    scan_directories = ['app', 'config']
    exclude_patterns = [
      'app/assets/**/*',
      'app/javascript/**/*',
      'config/credentials*',
      'config/master.key',
      'config/database.yml',
      '**/.*', # Hidden files
      '**/*.log',
      '**/*.tmp',
      '**/*.swp',
      '**/*.bak'
    ]
    
    # Define file extensions to include
    include_extensions = ['.rb', '.yml', '.yaml', '.json', '.md', '.rake']
    
    imported_count = 0
    skipped_count = 0
    error_count = 0
    processed_files = []
    
    puts "📁 Scanning directories: #{scan_directories.join(', ')}"
    puts "🚫 Excluding patterns: #{exclude_patterns.join(', ')}"
    puts "📄 Including extensions: #{include_extensions.join(', ')}"
    puts "-" * 60
    
    scan_directories.each do |dir|
      dir_path = Rails.root.join(dir)
      unless Dir.exist?(dir_path)
        puts "⚠️  Directory not found: #{dir_path}"
        next
      end
      
      # Find all files in the directory
      Dir.glob(File.join(dir_path, '**', '*')).each do |file_path|
        next unless File.file?(file_path)
        
        # Check if file extension is included
        next unless include_extensions.include?(File.extname(file_path))
        
        # Get relative path from Rails root
        relative_path = Pathname.new(file_path).relative_path_from(Rails.root).to_s
        
        # Check if file matches any exclude pattern
        excluded = exclude_patterns.any? { |pattern| File.fnmatch(pattern, relative_path) }
        next if excluded
        
        processed_files << { path: file_path, relative_path: relative_path }
      end
    end
    
    if processed_files.empty?
      puts "⚠️  No files found to process"
      exit 0
    end
    
    puts "📄 Found #{processed_files.length} files to process"
    puts "-" * 60
    
    processed_files.each_with_index do |file_info, index|
      file_path = file_info[:path]
      relative_path = file_info[:relative_path]
      
      # Check if document already exists
      source_url = "file://#{relative_path}"
      existing_doc = KnowledgeDocument.find_by(
        source_url: source_url,
        user: system_user,
        source_type: 'code'
      )
      
      if existing_doc
        puts "⏭️  [#{index + 1}/#{processed_files.length}] Skipping (already imported): #{relative_path}"
        skipped_count += 1
        next
      end
      
      begin
        print "📥 [#{index + 1}/#{processed_files.length}] Processing: #{relative_path}..."
        
        # Read file content
        content = File.read(file_path)
        
        # Skip empty files
        if content.strip.empty?
          puts " ⏭️  (empty file)"
          skipped_count += 1
          next
        end
        
        # Extract title from file path
        title = extract_code_title(relative_path, content)
        
        # Create enhanced content with file context
        enhanced_content = create_enhanced_content(relative_path, content)
        
        # Create knowledge document
        doc = KnowledgeDocument.create!(
          user: system_user,
          title: title,
          content: enhanced_content,
          source_type: 'code',
          source_url: source_url,
          metadata: {
            imported_at: Time.current.iso8601,
            file_path: relative_path,
            file_size: File.size(file_path),
            file_extension: File.extname(file_path),
            directory: File.dirname(relative_path),
            importer_version: '1.0',
            content_type: detect_content_type(file_path)
          }
        )
        
        # Process the document to create chunks and embeddings
        doc.process!
        
        puts " ✅ (#{doc.knowledge_chunks.count} chunks)"
        imported_count += 1
        
      rescue => e
        puts " ❌ Error: #{e.message}"
        error_count += 1
        Rails.logger.error "Failed to import #{file_path}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    
    puts "-" * 60
    puts "\n📊 Codebase Indexing Summary:"
    puts "   ✅ Imported: #{imported_count} files"
    puts "   ⏭️  Skipped: #{skipped_count} files (already imported or empty)"
    puts "   ❌ Errors: #{error_count} files" if error_count > 0
    puts "\n✨ Codebase indexing completed!"
    puts "🔍 You can now search your code using the knowledge base with source_type: 'code'"
  end
  
  desc "Clear all code documents from the knowledge base"
  task clear_code_docs: :environment do
    puts "🗑️  Clearing code documents..."
    
    system_user = User.find_by(email: 'system@allspark.ai')
    if system_user
      count = system_user.knowledge_documents.where(source_type: 'code').count
      
      if count > 0
        print "⚠️  This will delete #{count} code documents. Are you sure? (y/N): "
        response = STDIN.gets.chomp.downcase
        
        if response == 'y'
          system_user.knowledge_documents.where(source_type: 'code').destroy_all
          puts "✅ Deleted #{count} code documents"
        else
          puts "❌ Cancelled"
        end
      else
        puts "ℹ️  No code documents found"
      end
    else
      puts "ℹ️  No system user found"
    end
  end
  
  private
  
  def extract_title(file_path, content)
    # Try to extract title from first markdown heading
    first_heading = content.match(/^#\s+(.+)$/)
    if first_heading
      return first_heading[1].strip
    end
    
    # Otherwise, use filename without extension
    basename = File.basename(file_path, File.extname(file_path))
    # Convert underscores and hyphens to spaces and titleize
    basename.gsub(/[_-]/, ' ').split.map(&:capitalize).join(' ')
  end
  
  def extract_code_title(file_path, content)
    # For Ruby files, try to extract class/module name
    if file_path.end_with?('.rb')
      # Look for class or module definition
      class_match = content.match(/^class\s+([A-Z][A-Za-z0-9_:]*)/m)
      module_match = content.match(/^module\s+([A-Z][A-Za-z0-9_:]*)/m)
      
      if class_match
        return "#{class_match[1]} (#{File.basename(file_path)})"
      elsif module_match
        return "#{module_match[1]} (#{File.basename(file_path)})"
      end
    end
    
    # For config files, use descriptive names
    if file_path.start_with?('config/')
      case File.basename(file_path)
      when 'routes.rb'
        return 'Application Routes Configuration'
      when 'application.rb'
        return 'Application Configuration'
      when 'environment.rb'
        return 'Environment Configuration'
      end
    end
    
    # Default: use file path as title
    file_path
  end
  
  def create_enhanced_content(file_path, content)
    # Add context header to help with search and understanding
    header = "# File: #{file_path}\n"
    header += "# Type: #{detect_content_type(file_path)}\n"
    header += "# Directory: #{File.dirname(file_path)}\n"
    header += "# Extension: #{File.extname(file_path)}\n\n"
    
    # Add separator
    header += "---\n\n"
    
    # Return enhanced content
    header + content
  end
  
  def detect_content_type(file_path)
    case File.extname(file_path)
    when '.rb'
      if file_path.include?('controller')
        'Ruby Controller'
      elsif file_path.include?('model')
        'Ruby Model'
      elsif file_path.include?('service')
        'Ruby Service'
      elsif file_path.include?('job')
        'Ruby Job'
      elsif file_path.include?('helper')
        'Ruby Helper'
      elsif file_path.end_with?('.rake')
        'Rake Task'
      else
        'Ruby Code'
      end
    when '.yml', '.yaml'
      'YAML Configuration'
    when '.json'
      'JSON Configuration'
    when '.md'
      'Markdown Documentation'
    else
      'Code File'
    end
  end
end