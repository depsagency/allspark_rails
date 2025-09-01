# frozen_string_literal: true

# Google Drive API Service
#
# Provides methods for interacting with Google Drive API including:
# - File upload/download
# - Folder management
# - File sharing and permissions
# - Metadata operations
#
class GoogleDriveService
  include GoogleWorkspaceIntegration

  REQUIRED_SCOPES = [
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/drive.file"
  ].freeze

  def initialize(service_account_name: "drive_processor", impersonate_user: nil)
    @drive_service = setup_drive_client(service_account_name, impersonate_user)
  end

  # Upload a file to Google Drive
  #
  # @param file_path [String] Local path to the file
  # @param folder_id [String, nil] Parent folder ID (nil for root)
  # @param metadata [Hash] Additional file metadata
  # @return [Google::Apis::DriveV3::File] Uploaded file object
  def upload_file(file_path, folder_id: nil, metadata: {})
    raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

    file_metadata = Google::Apis::DriveV3::File.new(
      name: metadata[:name] || File.basename(file_path),
      parents: folder_id ? [ folder_id ] : nil,
      description: metadata[:description]
    )

    execute_with_retry("upload_file:#{File.basename(file_path)}") do
      @drive_service.create_file(
        file_metadata,
        upload_source: file_path,
        content_type: metadata[:content_type] || detect_content_type(file_path)
      )
    end
  end

  # Download a file from Google Drive
  #
  # @param file_id [String] Drive file ID
  # @param save_path [String] Local path to save the file
  # @return [String] Path to downloaded file
  def download_file(file_id, save_path)
    execute_with_retry("download_file:#{file_id}") do
      file_content = @drive_service.get_file(file_id, download_dest: StringIO.new)

      File.open(save_path, "wb") do |file|
        file.write(file_content)
      end

      save_path
    end
  end

  # List files in Drive
  #
  # @param query [String, nil] Search query
  # @param folder_id [String, nil] Folder to search in
  # @param page_size [Integer] Number of files per page
  # @return [Array<Google::Apis::DriveV3::File>] Array of files
  def list_files(query: nil, folder_id: nil, page_size: 100)
    search_query = build_search_query(query, folder_id)

    execute_with_retry("list_files") do
      response = @drive_service.list_files(
        q: search_query,
        page_size: page_size,
        fields: "nextPageToken, files(id, name, parents, createdTime, modifiedTime, size, mimeType, webViewLink)"
      )

      response.files || []
    end
  end

  # Create a folder in Drive
  #
  # @param name [String] Folder name
  # @param parent_id [String, nil] Parent folder ID
  # @return [Google::Apis::DriveV3::File] Created folder object
  def create_folder(name, parent_id: nil)
    folder_metadata = Google::Apis::DriveV3::File.new(
      name: name,
      parents: parent_id ? [ parent_id ] : nil,
      mime_type: "application/vnd.google-apps.folder"
    )

    execute_with_retry("create_folder:#{name}") do
      @drive_service.create_file(folder_metadata)
    end
  end

  # Move a file to a different folder
  #
  # @param file_id [String] File ID to move
  # @param new_parent_id [String] New parent folder ID
  # @return [Google::Apis::DriveV3::File] Updated file object
  def move_file(file_id, new_parent_id)
    # Get current parents
    file = get_file_metadata(file_id)
    previous_parents = file.parents&.join(",")

    execute_with_retry("move_file:#{file_id}") do
      @drive_service.update_file(
        file_id,
        add_parents: new_parent_id,
        remove_parents: previous_parents,
        fields: "id, parents"
      )
    end
  end

  # Delete a file
  #
  # @param file_id [String] File ID to delete
  # @return [void]
  def delete_file(file_id)
    execute_with_retry("delete_file:#{file_id}") do
      @drive_service.delete_file(file_id)
    end
  end

  # Share a file with specific permissions
  #
  # @param file_id [String] File ID to share
  # @param email [String] Email address to share with
  # @param role [String] Permission role ('reader', 'writer', 'owner')
  # @return [Google::Apis::DriveV3::Permission] Created permission
  def share_file(file_id, email, role: "reader")
    permission = Google::Apis::DriveV3::Permission.new(
      type: "user",
      role: role,
      email_address: email
    )

    execute_with_retry("share_file:#{file_id}:#{email}") do
      @drive_service.create_permission(file_id, permission)
    end
  end

  # Get file metadata
  #
  # @param file_id [String] File ID
  # @return [Google::Apis::DriveV3::File] File metadata
  def get_file_metadata(file_id)
    execute_with_retry("get_file_metadata:#{file_id}") do
      @drive_service.get_file(
        file_id,
        fields: "id, name, parents, createdTime, modifiedTime, size, mimeType, webViewLink, permissions"
      )
    end
  end

  # Sync a local folder with a Drive folder
  #
  # @param local_path [String] Local folder path
  # @param drive_folder_id [String] Drive folder ID
  # @param direction [Symbol] Sync direction (:up, :down, :both)
  # @return [Hash] Sync results
  def sync_folder(local_path, drive_folder_id, direction: :both)
    results = { uploaded: [], downloaded: [], errors: [] }

    case direction
    when :up, :both
      sync_local_to_drive(local_path, drive_folder_id, results)
    end

    case direction
    when :down, :both
      sync_drive_to_local(drive_folder_id, local_path, results)
    end

    results
  end

  # Setup webhook for file change notifications
  #
  # @param folder_id [String] Folder to watch
  # @param callback_url [String] Webhook URL
  # @return [Google::Apis::DriveV3::Channel] Created channel
  def setup_webhook(folder_id, callback_url)
    channel = Google::Apis::DriveV3::Channel.new(
      id: SecureRandom.uuid,
      type: "web_hook",
      address: callback_url
    )

    execute_with_retry("setup_webhook:#{folder_id}") do
      @drive_service.watch_file(folder_id, channel)
    end
  end

  private

  # Setup Drive API client
  def setup_drive_client(service_account_name, impersonate_user)
    authorizer = setup_google_auth(service_account_name, impersonate_user, REQUIRED_SCOPES)

    Google::Apis::DriveV3::DriveService.new.tap do |service|
      service.authorization = authorizer
    end
  end

  # Test API access by listing files
  def test_api_access
    execute_with_retry("test_connection") do
      @drive_service.list_files(page_size: 1)
    end
  end

  # Build search query for listing files
  def build_search_query(query, folder_id)
    parts = []
    parts << "name contains '#{query}'" if query.present?
    parts << "'#{folder_id}' in parents" if folder_id.present?
    parts << "trashed = false"

    parts.join(" and ")
  end

  # Detect content type from file extension
  def detect_content_type(file_path)
    case File.extname(file_path).downcase
    when ".pdf"
      "application/pdf"
    when ".txt"
      "text/plain"
    when ".jpg", ".jpeg"
      "image/jpeg"
    when ".png"
      "image/png"
    when ".doc"
      "application/msword"
    when ".docx"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    when ".xls"
      "application/vnd.ms-excel"
    when ".xlsx"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else
      "application/octet-stream"
    end
  end

  # Sync local folder to Drive
  def sync_local_to_drive(local_path, drive_folder_id, results)
    Dir.glob(File.join(local_path, "*")).each do |file_path|
      next if File.directory?(file_path)

      begin
        uploaded_file = upload_file(file_path, folder_id: drive_folder_id)
        results[:uploaded] << { local: file_path, drive_id: uploaded_file.id }
      rescue => e
        results[:errors] << { file: file_path, error: e.message }
      end
    end
  end

  # Sync Drive folder to local
  def sync_drive_to_local(drive_folder_id, local_path, results)
    FileUtils.mkdir_p(local_path) unless Dir.exist?(local_path)

    files = list_files(folder_id: drive_folder_id)

    files.each do |file|
      next if file.mime_type == "application/vnd.google-apps.folder"

      begin
        local_file_path = File.join(local_path, file.name)
        download_file(file.id, local_file_path)
        results[:downloaded] << { drive_id: file.id, local: local_file_path }
      rescue => e
        results[:errors] << { file: file.name, error: e.message }
      end
    end
  end
end
