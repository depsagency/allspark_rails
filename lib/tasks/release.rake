namespace :release do
  desc "Run all release phase tasks"
  task run: :environment do
    puts "Running release tasks..."

    # Create all databases if they don't exist
    %w[primary cache queue cable].each do |db_name|
      begin
        ActiveRecord::Base.establish_connection(db_name.to_sym)
        ActiveRecord::Base.connection
        puts "✓ #{db_name} database exists"
      rescue ActiveRecord::NoDatabaseError
        puts "Creating #{db_name} database..."
        ActiveRecord::Tasks::DatabaseTasks.create(
          ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: db_name).first
        )
        puts "✓ #{db_name} database created"
      end
    end

    # Run migrations for all databases
    puts "Running migrations..."
    Rake::Task["db:migrate"].invoke
    puts "✓ Migrations complete"
  end
end
