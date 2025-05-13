require 'rake'
require 'sequel'
require 'dotenv/load'
require 'csv'

# Connect to the database
DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/birds')

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
  
  desc 'Seed the database with sample data'
  task :seed do
    require_relative 'db/seed'
  end
  
  desc 'Debug database connection'
  task :debug do
    puts "Database URL: #{ENV['DATABASE_URL'] || 'postgres://localhost/birds'}"
    puts "Database connection info: #{DB.opts.inspect}"
    puts "Database tables: #{DB.tables.inspect}"
    puts "Current database schema version: #{DB[:schema_info].first[:version] rescue 'unknown'}"
  end
  
  desc 'Import node data from CSV or use sample data'
  task :import_csv do
    if !File.exist?('./data/nodes.csv')
      puts "Error: Could not find ./data/nodes.csv"
      exit 1
    end
    
    # Debug information
    puts "Database connection check before import:"
    puts "Database URL: #{ENV['DATABASE_URL']}"
    puts "Database tables: #{DB.tables.inspect}"
    
    puts "Clearing existing nodes data..."
    DB[:birds].delete
    DB[:nodes].delete
    
    puts "Node count after deletion: #{DB[:nodes].count}"
    
    puts "Temporarily disabling foreign key constraints..."
    DB.run("ALTER TABLE nodes DISABLE TRIGGER ALL;")
    
    puts "Importing nodes from CSV..."
    
    # First, count how many records are in the CSV
    total_nodes = 0
    CSV.foreach('./data/nodes.csv', headers: true) { |_| total_nodes += 1 }
    puts "Total nodes in CSV: #{total_nodes}"
    
    count = 0
    error_count = 0
    
    # Process in batches for better performance
    batch_size = 100  # Smaller batch size for debugging
    batch = []
    
    begin
      CSV.foreach('./data/nodes.csv', headers: true) do |row|
        count += 1
        
        # Debug output for the first few rows
        if count <= 5
          puts "Debug: Processing row #{count}: id=#{row['id']}, parent_id=#{row['parent_id']}"
        end
        
        # Convert to proper data types
        node = {
          id: row['id'].to_i,
          parent_id: row['parent_id'].nil? || row['parent_id'].to_s.strip == '' ? nil : row['parent_id'].to_i
        }
        
        batch << node
        
        if batch.size >= batch_size
          begin
            # Try to insert the batch
            puts "Inserting batch of #{batch.size} records..." if count <= 500
            DB[:nodes].multi_insert(batch)
            puts "Successfully inserted batch ending with record #{count}" if count <= 500
          rescue => e
            error_count += 1
            puts "Error inserting batch at count #{count}: #{e.message}"
            
            # Try inserting one by one to identify problem records
            if error_count <= 3  # Only do this for the first few errors
              puts "Trying individual inserts for problem batch..."
              batch.each do |node_record|
                begin
                  DB[:nodes].insert(node_record)
                rescue => e2
                  puts "Error inserting record: #{node_record.inspect} - #{e2.message}"
                end
              end
            end
          end
          
          batch = []
        end
      end
      
      # Insert any remaining records
      unless batch.empty?
        begin
          DB[:nodes].multi_insert(batch)
        rescue => e
          puts "Error inserting final batch: #{e.message}"
        end
      end
    rescue => e
      puts "Fatal error during CSV import: #{e.message}"
      puts e.backtrace.join("\n")
    end
    
    puts "Re-enabling foreign key constraints..."
    DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;")
    
    # Verify the import
    actual_count = DB[:nodes].count
    puts "Finished import attempt. Processed #{count} nodes from CSV. Database contains #{actual_count} nodes."
    
    # If import failed for some reason, use sample data instead
    if actual_count == 0
      puts "Import failed or no nodes were imported. Loading sample data instead..."
      
      # Insert sample nodes
      nodes_data = [
        { id: 130, parent_id: nil },
        { id: 125, parent_id: 130 },
        { id: 2820230, parent_id: 125 },
        { id: 4430546, parent_id: 125 },
        { id: 5497637, parent_id: 4430546 }
      ]
      
      nodes_data.each do |node_data|
        DB[:nodes].insert(node_data)
      end
      
      puts "Sample data loaded. Database now contains #{DB[:nodes].count} nodes."
    end
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