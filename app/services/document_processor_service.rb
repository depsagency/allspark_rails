# frozen_string_literal: true

class DocumentProcessorService
  def initialize(knowledge_document)
    @document = knowledge_document
  end
  
  def process!
    # Manually check for file attachment using string comparison
    attachment = ActiveStorage::Attachment.find_by(
      record_type: 'KnowledgeDocument',
      record_id: @document.id.to_s,
      name: 'file'
    )
    
    return unless attachment
    
    # Extract text from the attached file
    text = extract_text_from_file(attachment)
    
    # Save the extracted text to the document
    @document.update!(content: text)
    
    # Process the document (chunk and generate embeddings)
    @document.process!
    
    true
  rescue => e
    Rails.logger.error "Document processing failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
  
  private
  
  def extract_text_from_file(attachment)
    return "" unless attachment
    
    blob = attachment.blob
    case blob.content_type
    when "text/plain"
      extract_text_from_txt(blob)
    when "text/markdown", "text/x-markdown"
      extract_text_from_markdown(blob)
    when "application/pdf"
      extract_text_from_pdf(blob)
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_text_from_docx(blob)
    when "text/html"
      extract_text_from_html(blob)
    else
      raise "Unsupported file type: #{blob.content_type}"
    end
  end
  
  def extract_text_from_txt(blob)
    blob.download
  end
  
  def extract_text_from_markdown(blob)
    blob.download
  end
  
  def extract_text_from_pdf(blob)
    # For PDF extraction, we'll use a simple approach
    # In production, you'd want to use a gem like pdf-reader
    require 'open3'
    
    Tempfile.create(['document', '.pdf']) do |temp_file|
      temp_file.binmode
      temp_file.write(blob.download)
      temp_file.rewind
      
      # Use pdftotext if available (common in Linux)
      stdout, stderr, status = Open3.capture3("pdftotext", "-layout", temp_file.path, "-")
      
      if status.success?
        stdout
      else
        # Fallback: return a placeholder
        "[PDF content - install pdftotext for extraction]"
      end
    end
  rescue => e
    Rails.logger.warn "PDF extraction failed: #{e.message}"
    "[PDF content - extraction failed]"
  end
  
  def extract_text_from_docx(blob)
    # For DOCX extraction, we'll use a simple approach
    # In production, you'd want to use a gem like docx
    require 'zip'
    require 'nokogiri'
    
    text_content = []
    
    Tempfile.create(['document', '.docx']) do |temp_file|
      temp_file.binmode
      temp_file.write(blob.download)
      temp_file.rewind
      
      Zip::File.open(temp_file.path) do |zip_file|
        # Extract text from document.xml
        doc_entry = zip_file.find_entry('word/document.xml')
        if doc_entry
          xml_content = doc_entry.get_input_stream.read
          doc = Nokogiri::XML(xml_content)
          
          # Extract all text nodes
          doc.xpath('//w:t', 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main').each do |text_node|
            text_content << text_node.text
          end
        end
      end
    end
    
    text_content.join(' ')
  rescue => e
    Rails.logger.warn "DOCX extraction failed: #{e.message}"
    "[DOCX content - extraction failed]"
  end
  
  def extract_text_from_html(blob)
    require 'nokogiri'
    
    html_content = blob.download
    doc = Nokogiri::HTML(html_content)
    
    # Remove script and style elements
    doc.css('script, style').each(&:remove)
    
    # Extract text
    doc.text.gsub(/\s+/, ' ').strip
  rescue => e
    Rails.logger.warn "HTML extraction failed: #{e.message}"
    "[HTML content - extraction failed]"
  end
end