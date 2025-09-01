# frozen_string_literal: true

namespace :monitoring do
  desc "Check application health and performance"
  task health: :environment do
    puts "🏥 Running health checks..."

    # Database connectivity
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Database: Connected"
    rescue => e
      puts "❌ Database: #{e.message}"
    end

    # Redis connectivity
    begin
      if defined?(Redis)
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
        redis.ping
        puts "✅ Redis: Connected"
      else
        puts "⚠️  Redis: Not configured"
      end
    rescue => e
      puts "❌ Redis: #{e.message}"
    end

    # Sidekiq status
    begin
      if defined?(Sidekiq)
        stats = Sidekiq::Stats.new
        puts "✅ Sidekiq: #{stats.processed} processed, #{stats.failed} failed, #{stats.retry_size} retrying"
      else
        puts "⚠️  Sidekiq: Not configured"
      end
    rescue => e
      puts "❌ Sidekiq: #{e.message}"
    end

    # Disk space
    begin
      disk_usage = `df -h #{Rails.root}`.split("\n")[1].split
      puts "💾 Disk usage: #{disk_usage[4]} used (#{disk_usage[2]} / #{disk_usage[1]})"
    rescue => e
      puts "⚠️  Disk space: Could not check (#{e.message})"
    end

    # Memory usage
    begin
      if defined?(GC)
        gc_stats = GC.stat
        puts "🧠 Memory: #{gc_stats[:heap_live_slots]} live objects, #{gc_stats[:count]} GC runs"
      end
    rescue => e
      puts "⚠️  Memory: Could not check (#{e.message})"
    end

    puts "\n✅ Health check completed"
  end

  desc "Show performance metrics"
  task metrics: :environment do
    puts "📊 Performance Metrics"
    puts "=" * 50

    # Database metrics
    if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      begin
        db_size = ActiveRecord::Base.connection.execute(
          "SELECT pg_size_pretty(pg_database_size(current_database()))"
        ).first["pg_size_pretty"]
        puts "Database size: #{db_size}"

        table_sizes = ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT schemaname,tablename,pg_size_pretty(size) as size
          FROM (
            SELECT schemaname,tablename,pg_total_relation_size(schemaname||'.'||tablename) AS size
            FROM pg_tables WHERE schemaname = 'public'
          ) AS sizes
          ORDER BY size DESC
          LIMIT 10
        SQL

        puts "\nLargest tables:"
        table_sizes.each do |table|
          puts "  #{table['tablename']}: #{table['size']}"
        end
      rescue => e
        puts "Could not fetch database metrics: #{e.message}"
      end
    end

    # Cache metrics (if Redis is available)
    begin
      if defined?(Rails.cache) && Rails.cache.respond_to?(:redis)
        info = Rails.cache.redis.info
        puts "\nRedis metrics:"
        puts "  Memory used: #{info['used_memory_human']}"
        puts "  Total keys: #{info['db0']&.match(/keys=(\d+)/)&.[](1) || '0'}"
        puts "  Connected clients: #{info['connected_clients']}"
      end
    rescue => e
      puts "Could not fetch cache metrics: #{e.message}"
    end

    # Log file sizes
    begin
      log_dir = Rails.root.join("log")
      if Dir.exist?(log_dir)
        puts "\nLog file sizes:"
        Dir.glob(log_dir.join("*.log")).each do |log_file|
          size = File.size(log_file)
          size_mb = (size / 1024.0 / 1024.0).round(2)
          puts "  #{File.basename(log_file)}: #{size_mb} MB"
        end
      end
    rescue => e
      puts "Could not check log files: #{e.message}"
    end
  end

  desc "Clean up old logs and temporary files"
  task cleanup: :environment do
    puts "🧹 Cleaning up old files..."

    cleaned_count = 0

    # Clean old log files (keep last 7 days)
    begin
      log_dir = Rails.root.join("log")
      if Dir.exist?(log_dir)
        old_logs = Dir.glob(log_dir.join("*.log.*")).select do |file|
          File.mtime(file) < 7.days.ago
        end

        old_logs.each do |file|
          File.delete(file)
          cleaned_count += 1
          puts "  Deleted #{File.basename(file)}"
        end
      end
    rescue => e
      puts "Error cleaning log files: #{e.message}"
    end

    # Clean temporary files
    begin
      tmp_dir = Rails.root.join("tmp")
      if Dir.exist?(tmp_dir)
        old_tmp_files = Dir.glob(tmp_dir.join("**/*")).select do |file|
          File.file?(file) && File.mtime(file) < 1.day.ago
        end

        old_tmp_files.each do |file|
          File.delete(file)
          cleaned_count += 1
        end
      end
    rescue => e
      puts "Error cleaning temporary files: #{e.message}"
    end

    # Clean cache (if configured)
    begin
      Rails.cache.clear
      puts "  Cleared application cache"
    rescue => e
      puts "Error clearing cache: #{e.message}"
    end

    puts "✅ Cleanup completed (#{cleaned_count} files removed)"
  end

  desc "Generate performance report"
  task report: :environment do
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    report_file = Rails.root.join("tmp/performance_report_#{timestamp}.txt")

    puts "📝 Generating performance report..."

    File.open(report_file, "w") do |f|
      f.puts "Performance Report - #{Time.current}"
      f.puts "=" * 50
      f.puts

      # System information
      f.puts "System Information:"
      f.puts "  Rails version: #{Rails::VERSION::STRING}"
      f.puts "  Ruby version: #{RUBY_VERSION}"
      f.puts "  Environment: #{Rails.env}"
      f.puts "  Database: #{ActiveRecord::Base.connection.adapter_name}"
      f.puts

      # Database statistics
      begin
        f.puts "Database Statistics:"
        ActiveRecord::Base.descendants.each do |model|
          next unless model.table_exists?
          count = model.count
          f.puts "  #{model.name}: #{count} records"
        end
        f.puts
      rescue => e
        f.puts "  Error fetching database stats: #{e.message}"
        f.puts
      end

      # Job statistics (if Sidekiq is available)
      begin
        if defined?(Sidekiq)
          stats = Sidekiq::Stats.new
          f.puts "Job Statistics:"
          f.puts "  Processed: #{stats.processed}"
          f.puts "  Failed: #{stats.failed}"
          f.puts "  Retries: #{stats.retry_size}"
          f.puts "  Enqueued: #{stats.enqueued}"
          f.puts "  Dead: #{stats.dead_size}"
          f.puts
        end
      rescue => e
        f.puts "Job Statistics: Error (#{e.message})"
        f.puts
      end

      # Memory and GC statistics
      begin
        if defined?(GC)
          gc_stats = GC.stat
          f.puts "Memory & GC Statistics:"
          f.puts "  Live objects: #{gc_stats[:heap_live_slots]}"
          f.puts "  Free objects: #{gc_stats[:heap_free_slots]}"
          f.puts "  GC runs: #{gc_stats[:count]}"
          f.puts "  Total allocated: #{gc_stats[:total_allocated_objects]}"
          f.puts
        end
      rescue => e
        f.puts "Memory Statistics: Error (#{e.message})"
        f.puts
      end

      f.puts "Report generated at #{Time.current}"
    end

    puts "✅ Report saved to #{report_file}"
  end

  desc "Monitor application in real-time"
  task watch: :environment do
    puts "👀 Starting real-time monitoring (Ctrl+C to stop)..."
    puts "=" * 50

    trap("INT") { puts "\n🛑 Monitoring stopped"; exit }

    loop do
      system("clear") || system("cls")
      puts "Real-time Application Monitor - #{Time.current.strftime('%H:%M:%S')}"
      puts "=" * 50

      # Active connections
      begin
        if defined?(Sidekiq)
          stats = Sidekiq::Stats.new
          puts "📊 Jobs: #{stats.enqueued} enqueued, #{stats.retry_size} retrying"
        end
      rescue => e
        puts "❌ Jobs: Error (#{e.message})"
      end

      # Memory usage
      begin
        if defined?(GC)
          gc_stats = GC.stat
          puts "🧠 Memory: #{gc_stats[:heap_live_slots]} objects, #{gc_stats[:count]} GC runs"
        end
      rescue => e
        puts "❌ Memory: Error (#{e.message})"
      end

      # Database connections
      begin
        pool = ActiveRecord::Base.connection_pool
        puts "🔗 DB Pool: #{pool.connections.size}/#{pool.size} connections"
      rescue => e
        puts "❌ DB Pool: Error (#{e.message})"
      end

      # Recent log entries (last 5)
      begin
        log_file = Rails.root.join("log", "#{Rails.env}.log")
        if File.exist?(log_file)
          lines = `tail -5 #{log_file}`.split("\n")
          puts "\n📜 Recent logs:"
          lines.each { |line| puts "  #{line[0..100]}#{'...' if line.length > 100}" }
        end
      rescue => e
        puts "❌ Logs: Error (#{e.message})"
      end

      sleep 5
    end
  end

  desc "Check for potential issues"
  task check: :environment do
    puts "🔍 Checking for potential issues..."
    issues = []

    # Check for large log files
    begin
      log_dir = Rails.root.join("log")
      if Dir.exist?(log_dir)
        Dir.glob(log_dir.join("*.log")).each do |log_file|
          size_mb = File.size(log_file) / 1024.0 / 1024.0
          if size_mb > 100
            issues << "Large log file: #{File.basename(log_file)} (#{size_mb.round(2)} MB)"
          end
        end
      end
    rescue => e
      issues << "Could not check log files: #{e.message}"
    end

    # Check for failed jobs
    begin
      if defined?(Sidekiq)
        stats = Sidekiq::Stats.new
        if stats.failed > 100
          issues << "High number of failed jobs: #{stats.failed}"
        end
        if stats.retry_size > 50
          issues << "High number of retrying jobs: #{stats.retry_size}"
        end
      end
    rescue => e
      issues << "Could not check job stats: #{e.message}"
    end

    # Check database size (PostgreSQL only)
    begin
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        result = ActiveRecord::Base.connection.execute(
          "SELECT pg_database_size(current_database())"
        ).first["pg_database_size"]

        size_gb = result / 1024.0 / 1024.0 / 1024.0
        if size_gb > 10
          issues << "Large database size: #{size_gb.round(2)} GB"
        end
      end
    rescue => e
      # Silently ignore database size check errors
    end

    if issues.empty?
      puts "✅ No issues detected"
    else
      puts "⚠️  Issues detected:"
      issues.each { |issue| puts "  - #{issue}" }
    end
  end
end
