# frozen_string_literal: true

# Job for syncing files between local storage and Google Drive
#
# Handles:
# - Uploading local files to Drive
# - Downloading Drive files locally
# - Bi-directional synchronization
# - Progress tracking and error handling
#
class GoogleDriveSyncJob < GoogleWorkspaceJob
  # Sync local folder with Google Drive folder
  #
  # @param local_path [String] Local folder path
  # @param drive_folder_id [String] Google Drive folder ID
  # @param direction [String] Sync direction ('up', 'down', 'both')
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform(local_path, drive_folder_id, direction: "both", service_account_name: "drive_processor", impersonate_user: nil)
    @drive_service = GoogleDriveService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "drive_sync_#{direction}_#{File.basename(local_path)}"

    execute_with_progress(operation_name) do |progress|
      sync_results = @drive_service.sync_folder(local_path, drive_folder_id, direction: direction.to_sym)

      progress[:results] = sync_results
      progress[:uploaded_count] = sync_results[:uploaded].count
      progress[:downloaded_count] = sync_results[:downloaded].count
      progress[:error_count] = sync_results[:errors].count

      # Log detailed results
      Rails.logger.info "Drive sync completed: #{sync_results}"

      sync_results
    end
  end

  # Upload specific files to Google Drive
  #
  # @param file_paths [Array<String>] Local file paths to upload
  # @param drive_folder_id [String] Destination folder in Drive
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_upload(file_paths, drive_folder_id, service_account_name: "drive_processor", impersonate_user: nil)
    @drive_service = GoogleDriveService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "drive_upload_#{file_paths.count}_files"

    execute_with_progress(operation_name, file_paths.count) do |progress|
      uploaded_files = []

      file_paths.each do |file_path|
        begin
          if File.exist?(file_path)
            uploaded_file = @drive_service.upload_file(file_path, folder_id: drive_folder_id)
            uploaded_files << {
              local_path: file_path,
              drive_id: uploaded_file.id,
              drive_name: uploaded_file.name,
              web_view_link: uploaded_file.web_view_link
            }

            Rails.logger.info "Uploaded file: #{file_path} -> Drive ID: #{uploaded_file.id}"
          else
            error_message = "File not found: #{file_path}"
            add_error(progress, error_message)
            Rails.logger.warn error_message
          end
        rescue => error
          error_message = "Failed to upload #{file_path}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:uploaded_files] = uploaded_files
      uploaded_files
    end
  end

  # Download specific files from Google Drive
  #
  # @param file_mappings [Array<Hash>] Array of {drive_id:, local_path:} mappings
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_download(file_mappings, service_account_name: "drive_processor", impersonate_user: nil)
    @drive_service = GoogleDriveService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "drive_download_#{file_mappings.count}_files"

    execute_with_progress(operation_name, file_mappings.count) do |progress|
      downloaded_files = []

      file_mappings.each do |mapping|
        begin
          drive_id = mapping[:drive_id]
          local_path = mapping[:local_path]

          # Ensure directory exists
          FileUtils.mkdir_p(File.dirname(local_path))

          downloaded_path = @drive_service.download_file(drive_id, local_path)
          downloaded_files << {
            drive_id: drive_id,
            local_path: downloaded_path,
            file_size: File.size(downloaded_path)
          }

          Rails.logger.info "Downloaded file: Drive ID #{drive_id} -> #{downloaded_path}"
        rescue => error
          error_message = "Failed to download Drive ID #{mapping[:drive_id]}: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        ensure
          update_progress(progress)
        end
      end

      progress[:downloaded_files] = downloaded_files
      downloaded_files
    end
  end

  # Organize files in Drive by moving them to appropriate folders
  #
  # @param file_organization_rules [Array<Hash>] Rules for organizing files
  # @param service_account_name [String] Service account to use
  # @param impersonate_user [String] User to impersonate
  def perform_organization(file_organization_rules, service_account_name: "drive_processor", impersonate_user: nil)
    @drive_service = GoogleDriveService.new(
      service_account_name: service_account_name,
      impersonate_user: impersonate_user
    )

    operation_name = "drive_organization"

    execute_with_progress(operation_name) do |progress|
      organized_files = []

      file_organization_rules.each do |rule|
        begin
          # List files matching the rule criteria
          files = @drive_service.list_files(
            query: rule[:query],
            folder_id: rule[:source_folder_id]
          )

          progress[:total] += files.count

          files.each do |file|
            begin
              @drive_service.move_file(file.id, rule[:destination_folder_id])
              organized_files << {
                file_id: file.id,
                file_name: file.name,
                moved_to: rule[:destination_folder_id]
              }

              Rails.logger.info "Organized file: #{file.name} -> Folder #{rule[:destination_folder_id]}"
            rescue => error
              error_message = "Failed to move file #{file.name}: #{error.message}"
              add_error(progress, error_message)
              Rails.logger.error error_message
            ensure
              update_progress(progress)
            end
          end
        rescue => error
          error_message = "Failed to process organization rule: #{error.message}"
          add_error(progress, error_message)
          Rails.logger.error error_message
        end
      end

      progress[:organized_files] = organized_files
      organized_files
    end
  end
end
