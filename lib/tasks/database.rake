namespace :db do
  desc 'Run migrations'
  task :migrate do
    Sequel.extension :migration
    
    # Try different migration paths to support running from docker container or locally
    migration_paths = ['./db/migrations', './migrations']
    
    migration_path = migration_paths.find { |path| Dir.exist?(path) }
    
    if migration_path
      puts "Migrating to latest"
      Sequel::Migrator.run(DB, migration_path)
      puts "Migrations complete"
    else
      puts "Migration directory not found in: #{migration_paths.join(', ')}"
    end
  end
  
  desc 'Rollback last migration'
  task :rollback do
    Sequel.extension :migration
    
    migration_paths = ['./db/migrations', './migrations']
    migration_path = migration_paths.find { |path| Dir.exist?(path) }
    
    if migration_path
      steps = ENV['STEPS'] ? ENV['STEPS'].to_i : 1
      Sequel::Migrator.run(DB, migration_path, :relative => -steps)
      puts "Rolled back #{steps} #{'step'.pluralize(steps)}"
    else
      puts "Migration directory not found in: #{migration_paths.join(', ')}"
    end
  end
  
  desc 'Debug database connection'
  task :debug do
    puts "Database URL: #{ENV['DATABASE_URL'] || 'postgres://localhost/birds'}"
    puts "Database connection info: #{DB.opts.inspect}"
    puts "Database tables: #{DB.tables.inspect}"
    puts "Current database schema version: #{DB[:schema_info].first[:version] rescue 'unknown'}"
  end
  
  desc 'Reset database: migrate, import CSV, then seed birds'
  task :reset => [:migrate, :import_csv] do
    puts "Creating birds data..."
    # Add some birds to random nodes
    bird_count = 1000
    node_ids = DB[:nodes].select_map(:id)
    
    if node_ids.empty?
      puts "No nodes found to attach birds to!"
    else
      # Create birds with random node assignments
      birds_data = []
      bird_count.times do
        random_node_id = node_ids.sample
        birds_data << { node_id: random_node_id }
      end
      
      DB[:birds].multi_insert(birds_data)
      puts "Created #{bird_count} birds on random nodes"
    end
    
    puts "Database reset complete! Final counts:"
    puts "Nodes: #{DB[:nodes].count}"
    puts "Birds: #{DB[:birds].count}"
    
    # Show some sample nodes
    puts "Sample nodes in database:"
    DB[:nodes].limit(10).each do |node|
      puts "  Node: #{node.inspect}"
    end
  end
end 