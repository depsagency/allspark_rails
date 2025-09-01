# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_31_010220) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.string "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "activity_type"
    t.text "details"
    t.datetime "activity_date"
    t.uuid "company_id"
    t.uuid "person_id"
    t.uuid "opportunity_id"
    t.integer "copper_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "copper_user_id"
    t.index ["company_id"], name: "index_activities_on_company_id"
    t.index ["copper_id"], name: "index_activities_on_copper_id", unique: true
    t.index ["copper_user_id"], name: "index_activities_on_copper_user_id"
    t.index ["opportunity_id"], name: "index_activities_on_opportunity_id"
    t.index ["person_id"], name: "index_activities_on_person_id"
  end

  create_table "agent_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assistant_id", null: false
    t.uuid "user_id"
    t.string "run_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assistant_id"], name: "index_agent_runs_on_assistant_id"
    t.index ["created_at"], name: "index_agent_runs_on_created_at"
    t.index ["run_id"], name: "index_agent_runs_on_run_id", unique: true
    t.index ["status"], name: "index_agent_runs_on_status"
    t.index ["user_id"], name: "index_agent_runs_on_user_id"
  end

  create_table "agent_team_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_team_id", null: false
    t.text "task", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.json "result_data"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_team_id"], name: "index_agent_team_executions_on_agent_team_id"
    t.index ["created_at"], name: "index_agent_team_executions_on_created_at"
    t.index ["status"], name: "index_agent_team_executions_on_status"
  end

  create_table "agent_teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.text "purpose"
    t.json "configuration", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "workflow"
    t.index ["active"], name: "index_agent_teams_on_active"
    t.index ["name"], name: "index_agent_teams_on_name"
    t.index ["user_id"], name: "index_agent_teams_on_user_id"
  end

  create_table "agent_teams_assistants", id: false, force: :cascade do |t|
    t.uuid "agent_team_id", null: false
    t.uuid "assistant_id", null: false
    t.index ["agent_team_id", "assistant_id"], name: "idx_teams_assistants", unique: true
    t.index ["agent_team_id"], name: "index_agent_teams_assistants_on_agent_team_id"
    t.index ["assistant_id"], name: "index_agent_teams_assistants_on_assistant_id"
  end

  create_table "ai_generations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "app_project_id", null: false
    t.string "generation_type", null: false
    t.string "llm_provider", null: false
    t.string "model_used"
    t.text "input_prompt", null: false
    t.text "raw_output"
    t.integer "token_count"
    t.decimal "cost", precision: 10, scale: 4
    t.float "processing_time_seconds"
    t.string "status", default: "pending"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_project_id"], name: "index_ai_generations_on_app_project_id"
    t.index ["generation_type"], name: "index_ai_generations_on_generation_type"
    t.index ["llm_provider"], name: "index_ai_generations_on_llm_provider"
    t.index ["status"], name: "index_ai_generations_on_status"
  end

  create_table "alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "message"
    t.datetime "read_at"
    t.uuid "user_id", null: false
    t.string "alert_type"
    t.uuid "alertable_id"
    t.string "alertable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type"], name: "index_alerts_on_alert_type"
    t.index ["alertable_type", "alertable_id"], name: "index_alerts_on_alertable"
    t.index ["created_at"], name: "index_alerts_on_created_at"
    t.index ["read_at"], name: "index_alerts_on_read_at"
    t.index ["user_id", "read_at"], name: "index_alerts_on_user_read_status"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "allspark_chat_messages", force: :cascade do |t|
    t.bigint "chat_thread_id", null: false
    t.uuid "user_id", null: false
    t.text "content", null: false
    t.boolean "edited", default: false
    t.datetime "edited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_thread_id"], name: "index_allspark_chat_messages_on_chat_thread_id"
    t.index ["created_at"], name: "index_allspark_chat_messages_on_created_at"
  end

  create_table "allspark_chat_thread_participants", force: :cascade do |t|
    t.bigint "chat_thread_id", null: false
    t.uuid "user_id", null: false
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_thread_id", "user_id"], name: "idx_on_chat_thread_id_user_id_f92889c49e", unique: true
    t.index ["chat_thread_id"], name: "index_allspark_chat_thread_participants_on_chat_thread_id"
  end

  create_table "allspark_chat_threads", force: :cascade do |t|
    t.string "name", null: false
    t.string "context_type"
    t.bigint "context_id"
    t.uuid "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context_type", "context_id"], name: "index_allspark_chat_threads_on_context"
    t.index ["context_type", "context_id"], name: "index_allspark_chat_threads_on_context_type_and_context_id"
  end

  create_table "app_projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "draft"
    t.text "vision_response"
    t.text "users_response"
    t.text "journeys_response"
    t.text "features_response"
    t.text "technical_response"
    t.text "integrations_response"
    t.text "success_response"
    t.text "competition_response"
    t.text "design_response"
    t.text "challenges_response"
    t.text "generated_prd"
    t.text "generated_tasks"
    t.text "generated_claude_prompt"
    t.jsonb "generation_metadata", default: {}
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "generated_logo_url"
    t.text "logo_prompt"
    t.jsonb "logo_generation_metadata", default: {}
    t.text "logo_data"
    t.uuid "generated_marketing_page_id"
    t.text "marketing_page_prompt"
    t.jsonb "marketing_page_metadata", default: {}
    t.text "generated_claude_md"
    t.jsonb "claude_md_metadata"
    t.string "working_directory"
    t.string "project_type", default: "project_kickoff"
    t.jsonb "design_tasks", default: {}
    t.index ["generated_logo_url"], name: "index_app_projects_on_generated_logo_url"
    t.index ["generated_marketing_page_id"], name: "index_app_projects_on_generated_marketing_page_id"
    t.index ["project_type"], name: "index_app_projects_on_project_type"
    t.index ["slug"], name: "index_app_projects_on_slug", unique: true
    t.index ["status"], name: "index_app_projects_on_status"
    t.index ["user_id"], name: "index_app_projects_on_user_id"
  end

  create_table "assistant_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assistant_id"
    t.string "role", null: false
    t.text "content"
    t.json "tool_calls", default: []
    t.string "tool_call_id"
    t.string "run_id"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assistant_id"], name: "index_assistant_messages_on_assistant_id"
    t.index ["created_at"], name: "index_assistant_messages_on_created_at"
    t.index ["role"], name: "index_assistant_messages_on_role"
    t.index ["run_id"], name: "index_assistant_messages_on_run_id"
  end

  create_table "assistants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "instructions"
    t.string "tool_choice", default: "auto"
    t.jsonb "tools", default: []
    t.string "model_provider"
    t.string "llm_model_name"
    t.boolean "active", default: true
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "tool_configs", default: {}
    t.index ["active"], name: "index_assistants_on_active"
    t.index ["name"], name: "index_assistants_on_name"
    t.index ["tools"], name: "index_assistants_on_tools", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_assistants_on_user_id"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "details", default: {}
    t.uuid "user_id", null: false
    t.uuid "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["details"], name: "index_audit_logs_on_details", using: :gin
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "chat_threads", force: :cascade do |t|
    t.string "title"
    t.string "ulid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "paused", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["metadata"], name: "index_chat_threads_on_metadata", using: :gin
    t.index ["ulid"], name: "index_chat_threads_on_ulid", unique: true
  end

  create_table "client_tiers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_client_tiers_on_created_at"
    t.index ["name"], name: "index_client_tiers_on_name", unique: true
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "client_tier_id", null: false
    t.string "shiphero_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_tier_id"], name: "index_clients_on_client_tier_id"
    t.index ["created_at"], name: "index_clients_on_created_at"
    t.index ["name"], name: "index_clients_on_name"
    t.index ["shiphero_customer_id"], name: "index_clients_on_shiphero_customer_id", unique: true
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.string "phone"
    t.string "website"
    t.string "email"
    t.integer "copper_id", null: false
    t.jsonb "research_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "industry"
    t.integer "employee_count"
    t.index ["copper_id"], name: "index_companies_on_copper_id", unique: true
  end

  create_table "exception_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "notes"
    t.string "status"
    t.uuid "user_id", null: false
    t.datetime "resolved_at"
    t.uuid "shipment_id", null: false
    t.string "exception_type"
    t.uuid "resolved_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_exception_logs_on_created_at"
    t.index ["exception_type"], name: "index_exception_logs_on_exception_type"
    t.index ["resolved_at"], name: "index_exception_logs_on_resolved_at"
    t.index ["resolved_by_user_id"], name: "index_exception_logs_on_resolved_by_user_id"
    t.index ["shipment_id"], name: "index_exception_logs_on_shipment_id"
    t.index ["status"], name: "index_exception_logs_on_status"
    t.index ["user_id"], name: "index_exception_logs_on_user_id"
  end

  create_table "external_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "service", null: false
    t.text "access_token", null: false
    t.text "refresh_token"
    t.datetime "expires_at"
    t.json "metadata", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "team_id"
    t.index ["active"], name: "index_external_integrations_on_active"
    t.index ["service"], name: "index_external_integrations_on_service"
    t.index ["user_id", "service"], name: "index_external_integrations_on_user_id_and_service", unique: true
    t.index ["user_id"], name: "index_external_integrations_on_user_id"
  end

  create_table "impersonation_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "impersonator_id", null: false
    t.uuid "impersonated_user_id", null: false
    t.string "action", null: false
    t.text "reason"
    t.string "ip_address"
    t.string "user_agent"
    t.string "session_id"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_impersonation_audit_logs_on_action"
    t.index ["impersonated_user_id", "started_at"], name: "idx_on_impersonated_user_id_started_at_27c5b505d4"
    t.index ["impersonated_user_id"], name: "index_impersonation_audit_logs_on_impersonated_user_id"
    t.index ["impersonator_id", "started_at"], name: "idx_on_impersonator_id_started_at_90691b5514"
    t.index ["impersonator_id"], name: "index_impersonation_audit_logs_on_impersonator_id"
    t.index ["session_id"], name: "index_impersonation_audit_logs_on_session_id"
  end

  create_table "knowledge_chunks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "knowledge_document_id"
    t.text "content", null: false
    t.integer "position", null: false
    t.text "embedding_data"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding", limit: 1536
    t.index "((metadata -> 'tags'::text))", name: "index_knowledge_chunks_on_metadata_tags", using: :gin
    t.index ["embedding"], name: "index_knowledge_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["knowledge_document_id", "position"], name: "index_knowledge_chunks_on_knowledge_document_id_and_position", unique: true
    t.index ["knowledge_document_id"], name: "index_knowledge_chunks_on_knowledge_document_id"
    t.index ["metadata"], name: "index_knowledge_chunks_on_metadata_gin", using: :gin
  end

  create_table "knowledge_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assistant_id"
    t.uuid "user_id"
    t.string "title", null: false
    t.text "content"
    t.string "source_type"
    t.string "source_url"
    t.jsonb "metadata", default: {}
    t.text "embedding_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "((metadata -> 'tags'::text))", name: "index_knowledge_documents_on_metadata_tags", using: :gin
    t.index "((metadata ->> 'category'::text))", name: "index_knowledge_documents_on_metadata_category"
    t.index "((metadata ->> 'priority'::text))", name: "index_knowledge_documents_on_metadata_priority"
    t.index "((metadata ->> 'project'::text))", name: "index_knowledge_documents_on_metadata_project"
    t.index "((metadata ->> 'visibility'::text))", name: "index_knowledge_documents_on_metadata_visibility"
    t.index ["assistant_id"], name: "index_knowledge_documents_on_assistant_id"
    t.index ["metadata"], name: "index_knowledge_documents_on_metadata_gin", using: :gin
    t.index ["source_type"], name: "index_knowledge_documents_on_source_type"
    t.index ["title"], name: "index_knowledge_documents_on_title"
    t.index ["user_id"], name: "index_knowledge_documents_on_user_id"
  end

  create_table "leads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.string "status"
    t.text "details"
    t.uuid "company_id"
    t.uuid "person_id"
    t.integer "copper_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_leads_on_company_id"
    t.index ["copper_id"], name: "index_leads_on_copper_id", unique: true
    t.index ["person_id"], name: "index_leads_on_person_id"
  end

  create_table "mcp_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "mcp_server_id", null: false
    t.uuid "assistant_id", null: false
    t.string "tool_name", null: false
    t.text "request_data"
    t.text "response_data"
    t.datetime "executed_at", null: false
    t.integer "status"
    t.integer "response_time_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "mcp_configuration_id"
    t.index ["assistant_id"], name: "index_mcp_audit_logs_on_assistant_id"
    t.index ["executed_at", "response_time_ms"], name: "index_mcp_audit_logs_on_executed_at_and_response_time"
    t.index ["executed_at", "response_time_ms"], name: "index_mcp_audit_logs_recent_successful", where: "(status = 0)"
    t.index ["executed_at"], name: "index_mcp_audit_logs_on_executed_at"
    t.index ["mcp_configuration_id"], name: "index_mcp_audit_logs_on_mcp_configuration_id"
    t.index ["mcp_server_id", "executed_at"], name: "index_mcp_audit_logs_on_mcp_server_id_and_executed_at"
    t.index ["mcp_server_id", "executed_at"], name: "index_mcp_audit_logs_on_server_and_executed_at"
    t.index ["mcp_server_id", "status", "executed_at"], name: "index_mcp_audit_logs_on_server_status_executed"
    t.index ["mcp_server_id"], name: "index_mcp_audit_logs_on_mcp_server_id"
    t.index ["status", "executed_at"], name: "index_mcp_audit_logs_on_status_and_executed_at"
    t.index ["tool_name", "executed_at"], name: "index_mcp_audit_logs_on_tool_and_executed_at"
    t.index ["user_id", "executed_at"], name: "index_mcp_audit_logs_on_user_and_executed_at"
    t.index ["user_id", "executed_at"], name: "index_mcp_audit_logs_on_user_id_and_executed_at"
    t.index ["user_id", "status", "executed_at"], name: "index_mcp_audit_logs_on_user_status_executed"
    t.index ["user_id"], name: "index_mcp_audit_logs_on_user_id"
    t.check_constraint "response_time_ms >= 0", name: "positive_response_time"
  end

  create_table "mcp_configurations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "owner_type", null: false
    t.uuid "owner_id", null: false
    t.string "name", null: false
    t.text "server_config"
    t.integer "server_type", default: 0, null: false
    t.boolean "enabled", default: true, null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_mcp_configurations_on_enabled"
    t.index ["owner_type", "owner_id"], name: "index_mcp_configurations_on_owner_type_and_owner_id"
    t.index ["server_type"], name: "index_mcp_configurations_on_server_type"
  end

  create_table "mcp_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "process_uuid", null: false
    t.uuid "user_id", null: false
    t.uuid "mcp_configuration_id", null: false
    t.integer "process_id"
    t.string "status", default: "starting", null: false
    t.datetime "started_at", null: false
    t.datetime "last_activity_at", null: false
    t.integer "restart_count", default: 0
    t.json "capabilities"
    t.json "tools"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_activity_at"], name: "index_mcp_processes_on_last_activity_at"
    t.index ["mcp_configuration_id"], name: "index_mcp_processes_on_mcp_configuration_id"
    t.index ["process_uuid"], name: "index_mcp_processes_on_process_uuid", unique: true
    t.index ["status"], name: "index_mcp_processes_on_status"
    t.index ["user_id", "mcp_configuration_id"], name: "idx_mcp_processes_on_user_and_config"
    t.index ["user_id"], name: "index_mcp_processes_on_user_id"
  end

  create_table "mcp_servers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "endpoint", null: false
    t.string "protocol_version", default: "1.0"
    t.integer "auth_type", default: 0, null: false
    t.text "config"
    t.text "credentials"
    t.integer "status", default: 0, null: false
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "transport_type", default: 0, null: false
    t.string "owner_type"
    t.uuid "owner_id"
    t.datetime "migrated_at"
    t.index ["auth_type", "status"], name: "index_mcp_servers_on_auth_type_and_status"
    t.index ["name", "user_id"], name: "index_mcp_servers_on_name_and_user_id", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["owner_type", "owner_id"], name: "index_mcp_servers_on_owner_type_and_owner_id"
    t.index ["status", "created_at"], name: "index_mcp_servers_on_status_and_created_at"
    t.index ["status"], name: "index_mcp_servers_on_status"
    t.index ["transport_type"], name: "index_mcp_servers_on_transport_type"
    t.index ["updated_at"], name: "index_mcp_servers_active_on_updated_at", where: "(status = 0)"
    t.index ["user_id", "status"], name: "index_mcp_servers_on_user_and_status"
    t.index ["user_id"], name: "index_mcp_servers_on_user_id"
    t.check_constraint "protocol_version::text = ANY (ARRAY['1.0'::character varying::text, '1.1'::character varying::text, '2.0'::character varying::text])", name: "valid_protocol_version"
  end

  create_table "mcp_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "config_template", null: false
    t.jsonb "required_fields", default: []
    t.string "category"
    t.string "icon_url"
    t.string "documentation_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_mcp_templates_on_category"
    t.index ["key"], name: "index_mcp_templates_on_key", unique: true
  end

  create_table "mcp_tool_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "mcp_configuration_id", null: false
    t.string "tool_name", null: false
    t.json "arguments"
    t.json "result"
    t.boolean "success", default: false, null: false
    t.integer "execution_time_ms"
    t.string "error_code"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_mcp_tool_executions_on_created_at"
    t.index ["mcp_configuration_id", "created_at"], name: "idx_mcp_tool_exec_on_config_and_time"
    t.index ["mcp_configuration_id"], name: "index_mcp_tool_executions_on_mcp_configuration_id"
    t.index ["success"], name: "index_mcp_tool_executions_on_success"
    t.index ["tool_name"], name: "index_mcp_tool_executions_on_tool_name"
    t.index ["user_id", "mcp_configuration_id", "tool_name"], name: "idx_mcp_tool_exec_on_user_config_tool"
    t.index ["user_id"], name: "index_mcp_tool_executions_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.string "sender_name"
    t.string "sender_type"
    t.bigint "chat_thread_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_thread_id"], name: "index_messages_on_chat_thread_id"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "sender_id"
    t.string "title", null: false
    t.text "message", null: false
    t.string "notification_type", default: "info", null: false
    t.string "action_url"
    t.json "metadata", default: {}
    t.datetime "read_at", precision: nil
    t.datetime "delivered_at", precision: nil
    t.datetime "expires_at", precision: nil
    t.integer "priority", default: 0
    t.boolean "persistent", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_notifications_on_expires_at"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["priority", "created_at"], name: "index_notifications_on_priority_and_created_at"
    t.index ["sender_id"], name: "index_notifications_on_sender_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "opportunities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.decimal "value", precision: 15, scale: 2
    t.integer "probability"
    t.string "stage"
    t.date "close_date"
    t.uuid "company_id", null: false
    t.uuid "person_id"
    t.uuid "user_id", null: false
    t.integer "copper_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_opportunities_on_company_id"
    t.index ["copper_id"], name: "index_opportunities_on_copper_id", unique: true
    t.index ["person_id"], name: "index_opportunities_on_person_id"
    t.index ["user_id"], name: "index_opportunities_on_user_id"
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.string "title"
    t.uuid "company_id", null: false
    t.integer "copper_id", null: false
    t.jsonb "research_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.index ["company_id"], name: "index_people_on_company_id"
    t.index ["copper_id"], name: "index_people_on_copper_id", unique: true
  end

  create_table "personas", force: :cascade do |t|
    t.string "name"
    t.text "prompt"
    t.bigint "chat_thread_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_thread_id"], name: "index_personas_on_chat_thread_id"
  end

  create_table "priority_scores", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "score", null: false
    t.uuid "shipment_id", null: false
    t.string "engine_version", null: false
    t.jsonb "scoring_factors", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_priority_scores_on_created_at"
    t.index ["engine_version"], name: "index_priority_scores_on_engine_version"
    t.index ["score"], name: "index_priority_scores_on_score"
    t.index ["scoring_factors"], name: "index_priority_scores_on_scoring_factors", using: :gin
    t.index ["shipment_id"], name: "index_priority_scores_on_shipment_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "sku", null: false
    t.string "name", null: false
    t.integer "backorder_quantity", default: 0, null: false
    t.string "shiphero_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_products_on_created_at"
    t.index ["name"], name: "index_products_on_name"
    t.index ["shiphero_product_id"], name: "index_products_on_shiphero_product_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "permissions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "shipment_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "details", default: {}
    t.uuid "user_id", null: false
    t.string "event_type"
    t.uuid "shipment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_shipment_events_on_created_at"
    t.index ["details"], name: "index_shipment_events_on_details", using: :gin
    t.index ["event_type"], name: "index_shipment_events_on_event_type"
    t.index ["shipment_id"], name: "index_shipment_events_on_shipment_id"
    t.index ["user_id"], name: "index_shipment_events_on_user_id"
  end

  create_table "shipment_line_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "shipment_id", null: false
    t.integer "quantity_expected", default: 0, null: false
    t.integer "quantity_received", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_shipment_line_items_on_created_at"
    t.index ["product_id"], name: "index_shipment_line_items_on_product_id"
    t.index ["shipment_id", "product_id"], name: "index_shipment_line_items_on_shipment_and_product", unique: true
    t.index ["shipment_id"], name: "index_shipment_line_items_on_shipment_id"
  end

  create_table "shipment_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_shipment_types_on_created_at"
    t.index ["name"], name: "index_shipment_types_on_name", unique: true
  end

  create_table "shipments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", null: false
    t.uuid "client_id", null: false
    t.datetime "arrived_at"
    t.datetime "completed_at"
    t.uuid "warehouse_id", null: false
    t.integer "priority_score", default: 0
    t.jsonb "synced_payload", default: {}
    t.datetime "sla_deadline_at"
    t.uuid "shipment_type_id", null: false
    t.datetime "shiphero_synced_at"
    t.datetime "processing_started_at"
    t.boolean "is_priority_overridden", default: false
    t.text "priority_override_reason"
    t.uuid "priority_override_user_id"
    t.string "shiphero_purchase_order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arrived_at"], name: "index_shipments_on_arrived_at"
    t.index ["client_id"], name: "index_shipments_on_client_id"
    t.index ["completed_at"], name: "index_shipments_on_completed_at"
    t.index ["created_at"], name: "index_shipments_on_created_at"
    t.index ["is_priority_overridden"], name: "index_shipments_on_is_priority_overridden"
    t.index ["priority_override_user_id"], name: "index_shipments_on_priority_override_user_id"
    t.index ["priority_score"], name: "index_shipments_on_priority_score"
    t.index ["processing_started_at"], name: "index_shipments_on_processing_started_at"
    t.index ["shiphero_purchase_order_id"], name: "index_shipments_on_shiphero_purchase_order_id", unique: true
    t.index ["shiphero_synced_at"], name: "index_shipments_on_shiphero_synced_at"
    t.index ["shipment_type_id"], name: "index_shipments_on_shipment_type_id"
    t.index ["sla_deadline_at"], name: "index_shipments_on_sla_deadline_at"
    t.index ["status"], name: "index_shipments_on_status"
    t.index ["synced_payload"], name: "index_shipments_on_synced_payload", using: :gin
    t.index ["warehouse_id"], name: "index_shipments_on_warehouse_id"
  end

  create_table "sla_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.index ["client_id"], name: "index_sla_profiles_on_client_id"
    t.index ["created_at"], name: "index_sla_profiles_on_created_at"
    t.index ["name"], name: "index_sla_profiles_on_name", unique: true
  end

  create_table "sync_logs", force: :cascade do |t|
    t.string "sync_type", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.integer "records_processed", default: 0
    t.integer "records_created", default: 0
    t.integer "records_updated", default: 0
    t.integer "records_failed", default: 0
    t.text "error_message"
    t.json "sync_details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_sync_logs_on_started_at"
    t.index ["status"], name: "index_sync_logs_on_status"
    t.index ["sync_type"], name: "index_sync_logs_on_sync_type"
  end

  create_table "tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "details"
    t.datetime "due_date"
    t.boolean "completed", default: false
    t.uuid "company_id"
    t.uuid "person_id"
    t.uuid "opportunity_id"
    t.integer "copper_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "copper_user_id"
    t.index ["company_id"], name: "index_tasks_on_company_id"
    t.index ["copper_id"], name: "index_tasks_on_copper_id", unique: true
    t.index ["copper_user_id"], name: "index_tasks_on_copper_user_id"
    t.index ["opportunity_id"], name: "index_tasks_on_opportunity_id"
    t.index ["person_id"], name: "index_tasks_on_person_id"
  end

  create_table "user_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "role_id", null: false
    t.datetime "granted_at"
    t.uuid "granted_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_at"], name: "index_user_roles_on_granted_at"
    t.index ["granted_by_id"], name: "index_user_roles_on_granted_by_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "copper_id"
    t.integer "role", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.text "bio"
    t.string "website"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.jsonb "social_links", default: {}
    t.text "ssh_public_key"
    t.boolean "email_notifications", default: true, null: false
    t.boolean "push_notifications", default: true, null: false
    t.boolean "sms_notifications", default: false, null: false
    t.string "digest_frequency", default: "daily", null: false
    t.jsonb "notification_preferences", default: {}
    t.string "timezone"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["copper_id"], name: "index_users_on_copper_id", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_notifications", "push_notifications"], name: "index_users_on_email_notifications_and_push_notifications"
    t.index ["notification_preferences"], name: "index_users_on_notification_preferences", using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["social_links"], name: "index_users_on_social_links", using: :gin
  end

  create_table "warehouses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_warehouses_on_created_at"
    t.index ["location"], name: "index_warehouses_on_location"
    t.index ["name"], name: "index_warehouses_on_name", unique: true
  end

  create_table "workflow_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workflow_id", null: false
    t.uuid "started_by", null: false
    t.string "status", default: "pending"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "execution_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
  end

  create_table "workflow_tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "workflow_execution_id", null: false
    t.string "node_id", null: false
    t.uuid "assistant_id"
    t.string "title"
    t.text "instructions"
    t.string "status", default: "pending"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "result_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assistant_id"], name: "index_workflow_tasks_on_assistant_id"
    t.index ["workflow_execution_id"], name: "index_workflow_tasks_on_workflow_execution_id"
  end

  create_table "workflows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.uuid "team_id", null: false
    t.uuid "user_id", null: false
    t.text "mermaid_definition"
    t.jsonb "flow_definition", default: {}
    t.string "status", default: "draft"
    t.integer "version", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_workflows_on_team_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "companies"
  add_foreign_key "activities", "opportunities"
  add_foreign_key "activities", "people"
  add_foreign_key "agent_runs", "assistants"
  add_foreign_key "agent_runs", "users"
  add_foreign_key "agent_team_executions", "agent_teams"
  add_foreign_key "agent_teams", "users"
  add_foreign_key "agent_teams_assistants", "agent_teams"
  add_foreign_key "agent_teams_assistants", "assistants"
  add_foreign_key "ai_generations", "app_projects"
  add_foreign_key "alerts", "users"
  add_foreign_key "allspark_chat_messages", "allspark_chat_threads", column: "chat_thread_id"
  add_foreign_key "allspark_chat_messages", "users"
  add_foreign_key "allspark_chat_thread_participants", "allspark_chat_threads", column: "chat_thread_id"
  add_foreign_key "allspark_chat_thread_participants", "users"
  add_foreign_key "allspark_chat_threads", "users", column: "created_by_id"
  add_foreign_key "app_projects", "pages", column: "generated_marketing_page_id"
  add_foreign_key "app_projects", "users"
  add_foreign_key "assistant_messages", "assistants"
  add_foreign_key "assistants", "users"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "clients", "client_tiers"
  add_foreign_key "exception_logs", "shipments"
  add_foreign_key "exception_logs", "users"
  add_foreign_key "exception_logs", "users", column: "resolved_by_user_id"
  add_foreign_key "external_integrations", "users"
  add_foreign_key "impersonation_audit_logs", "users", column: "impersonated_user_id"
  add_foreign_key "impersonation_audit_logs", "users", column: "impersonator_id"
  add_foreign_key "knowledge_chunks", "knowledge_documents"
  add_foreign_key "knowledge_documents", "assistants"
  add_foreign_key "knowledge_documents", "users"
  add_foreign_key "leads", "companies"
  add_foreign_key "leads", "people"
  add_foreign_key "mcp_audit_logs", "assistants"
  add_foreign_key "mcp_audit_logs", "mcp_configurations"
  add_foreign_key "mcp_audit_logs", "mcp_servers"
  add_foreign_key "mcp_audit_logs", "users"
  add_foreign_key "mcp_processes", "mcp_configurations"
  add_foreign_key "mcp_processes", "users"
  add_foreign_key "mcp_servers", "users"
  add_foreign_key "mcp_tool_executions", "mcp_configurations"
  add_foreign_key "mcp_tool_executions", "users"
  add_foreign_key "messages", "chat_threads"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "sender_id"
  add_foreign_key "opportunities", "companies"
  add_foreign_key "opportunities", "people"
  add_foreign_key "opportunities", "users"
  add_foreign_key "people", "companies"
  add_foreign_key "personas", "chat_threads"
  add_foreign_key "priority_scores", "shipments"
  add_foreign_key "shipment_events", "shipments"
  add_foreign_key "shipment_events", "users"
  add_foreign_key "shipment_line_items", "products"
  add_foreign_key "shipment_line_items", "shipments"
  add_foreign_key "shipments", "clients"
  add_foreign_key "shipments", "shipment_types"
  add_foreign_key "shipments", "users", column: "priority_override_user_id"
  add_foreign_key "shipments", "warehouses"
  add_foreign_key "sla_profiles", "clients"
  add_foreign_key "tasks", "companies"
  add_foreign_key "tasks", "opportunities"
  add_foreign_key "tasks", "people"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "users", column: "granted_by_id"
  add_foreign_key "workflow_executions", "users", column: "started_by"
  add_foreign_key "workflow_executions", "workflows"
  add_foreign_key "workflow_tasks", "assistants"
  add_foreign_key "workflow_tasks", "workflow_executions"
  add_foreign_key "workflows", "agent_teams", column: "team_id"
  add_foreign_key "workflows", "users"
end
