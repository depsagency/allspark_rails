# frozen_string_literal: true

namespace :quality do
  desc "Run all code quality checks"
  task all: [ :rubocop, :brakeman, :bundle_audit, :database_consistency, :test_coverage ]

  desc "Run RuboCop style checks"
  task :rubocop do
    puts "🔍 Running RuboCop..."
    system("bundle exec rubocop")
  end

  desc "Run Brakeman security scan"
  task :brakeman do
    puts "🔒 Running Brakeman security scan..."
    system("bundle exec brakeman -q")
  end

  desc "Run bundle audit for security vulnerabilities"
  task :bundle_audit do
    puts "📦 Running bundle audit..."
    system("bundle exec bundle-audit check --update")
  end

  desc "Check database consistency"
  task database_consistency: :environment do
    puts "🗄️  Checking database consistency..."

    # Check for missing indexes on foreign keys
    missing_indexes = []

    ActiveRecord::Base.connection.tables.each do |table|
      foreign_keys = ActiveRecord::Base.connection.foreign_keys(table)
      indexes = ActiveRecord::Base.connection.indexes(table)

      foreign_keys.each do |fk|
        column_name = fk.column
        has_index = indexes.any? { |idx| idx.columns.include?(column_name) }

        unless has_index
          missing_indexes << "#{table}.#{column_name}"
        end
      end
    end

    if missing_indexes.any?
      puts "⚠️  Missing indexes on foreign keys:"
      missing_indexes.each { |idx| puts "   - #{idx}" }
    else
      puts "✅ All foreign keys have indexes"
    end
  end

  desc "Auto-fix RuboCop offenses"
  task :fix do
    puts "🔧 Auto-fixing RuboCop offenses..."
    system("bundle exec rubocop -A")
  end

  desc "Generate security report"
  task :security_report do
    puts "🛡️  Generating security report..."

    report_dir = "tmp/security_reports"
    FileUtils.mkdir_p(report_dir)

    puts "Running Brakeman..."
    system("bundle exec brakeman -o #{report_dir}/brakeman_report.html")

    puts "Running bundle audit..."
    system("bundle exec bundle-audit check --output #{report_dir}/bundle_audit.txt")

    puts "✅ Security reports generated in #{report_dir}/"
  end

  desc "Check test coverage"
  task :test_coverage do
    puts "📊 Checking test coverage..."

    if File.exist?("coverage/.last_run.json")
      require "json"
      coverage_data = JSON.parse(File.read("coverage/.last_run.json"))
      line_coverage = coverage_data["result"]["line"].to_f

      puts "Current line coverage: #{line_coverage}%"

      if line_coverage < 80.0
        puts "⚠️  Coverage is below 80% threshold"
        exit 1
      else
        puts "✅ Coverage meets 80% threshold"
      end
    else
      puts "⚠️  No coverage data found. Run tests first with: bundle exec rspec"
      exit 1
    end
  end

  desc "Run quality checks with tests"
  task with_tests: :environment do
    puts "🧪 Running quality checks with tests..."

    # Run tests first to generate coverage
    puts "\n=== Running Tests ==="
    test_result = system("bundle exec rspec")

    unless test_result
      puts "❌ Tests failed. Fix tests before running quality checks."
      exit 1
    end

    # Run quality checks
    puts "\n=== Running Quality Checks ==="
    Rake::Task["quality:all"].invoke

    puts "\n✅ All quality checks and tests passed!"
  end

  desc "Generate comprehensive quality report"
  task report: :environment do
    puts "📋 Generating comprehensive quality report..."

    report_dir = "tmp/quality_reports"
    FileUtils.mkdir_p(report_dir)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")

    # Generate individual reports
    puts "Running RuboCop..."
    system("bundle exec rubocop --format html --out #{report_dir}/rubocop_#{timestamp}.html")

    puts "Running Brakeman..."
    system("bundle exec brakeman -o #{report_dir}/brakeman_#{timestamp}.html")

    puts "Running bundle audit..."
    system("bundle exec bundle-audit check --output #{report_dir}/bundle_audit_#{timestamp}.txt")

    # Generate test coverage report
    if File.exist?("coverage/index.html")
      FileUtils.cp_r("coverage", "#{report_dir}/coverage_#{timestamp}")
      puts "Coverage report copied"
    end

    # Generate summary report
    summary_file = "#{report_dir}/quality_summary_#{timestamp}.txt"
    File.open(summary_file, "w") do |f|
      f.puts "Quality Report Generated: #{Time.current}"
      f.puts "=" * 50
      f.puts

      # Test coverage
      if File.exist?("coverage/.last_run.json")
        coverage_data = JSON.parse(File.read("coverage/.last_run.json"))
        f.puts "Test Coverage:"
        f.puts "  Line Coverage: #{coverage_data['result']['line']}%"
        f.puts "  Branch Coverage: #{coverage_data['result']['branch']}%" if coverage_data["result"]["branch"]
        f.puts
      end

      # Test statistics
      spec_files = Dir.glob("spec/**/*_spec.rb").count
      f.puts "Test Statistics:"
      f.puts "  Total spec files: #{spec_files}"
      f.puts "  Factory files: #{Dir.glob("spec/factories/**/*.rb").count}"
      f.puts

      # Code statistics
      f.puts "Code Statistics:"
      f.puts "  Ruby files: #{Dir.glob("app/**/*.rb").count + Dir.glob("lib/**/*.rb").count}"
      f.puts "  Controllers: #{Dir.glob("app/controllers/**/*.rb").count}"
      f.puts "  Models: #{Dir.glob("app/models/**/*.rb").count}"
      f.puts "  Services: #{Dir.glob("app/services/**/*.rb").count}"
      f.puts "  Jobs: #{Dir.glob("app/jobs/**/*.rb").count}"
      f.puts "  Components: #{Dir.glob("app/components/**/*.rb").count}"
    end

    puts "✅ Quality reports generated in #{report_dir}/"
    puts "📊 Summary report: #{summary_file}"
  end
end
