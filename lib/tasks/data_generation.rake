desc 'Generate large dataset for performance testing'
task :generate_performance_data do
  require 'benchmark'
  
  # Configuration
  total_nodes = (ENV['NODES'] || 1_000_000).to_i
  max_children = 10
  max_depth = 20
  bird_ratio = 0.1  # Birds per node ratio
  batch_size = 10_000
  
  puts "Clearing existing data..."
  DB[:birds].delete
  DB[:nodes].delete
  
  puts "Temporarily disabling foreign key constraints..."
  DB.run("ALTER TABLE nodes DISABLE TRIGGER ALL;")
  
  # Create root node
  root_id = 1
  DB[:nodes].insert(id: root_id, parent_id: nil)
  
  puts "Generating #{total_nodes} nodes with max depth #{max_depth}..."
  
  current_id = 2
  parent_ids = [root_id]
  current_level = 1
  
  # Track progress
  last_report_time = Time.now
  report_interval = 5  # seconds
  
  node_batches = []
  
  begin
    time = Benchmark.measure do
      while current_id <= total_nodes && current_level <= max_depth
        new_parent_ids = []
        
        parent_ids.each do |parent_id|
          # Random number of children for this parent
          children_count = rand(1..max_children)
          
          children_count.times do
            break if current_id > total_nodes
            
            node_batches << {id: current_id, parent_id: parent_id}
            new_parent_ids << current_id
            current_id += 1
            
            # Insert in batches
            if node_batches.size >= batch_size
              DB[:nodes].multi_insert(node_batches)
              node_batches = []
              
              # Report progress periodically
              if Time.now - last_report_time > report_interval
                last_report_time = Time.now
                completion = ((current_id.to_f / total_nodes) * 100).round(2)
                puts "Progress: #{current_id}/#{total_nodes} nodes (#{completion}%) at level #{current_level}/#{max_depth}"
              end
            end
          end
        end
        
        parent_ids = new_parent_ids
        current_level += 1
        
        # If we've run out of parents but haven't reached our node count,
        # reset to use all existing nodes as parents for the next level
        if parent_ids.empty? && current_id <= total_nodes
          parent_ids = DB[:nodes].select_map(:id)
          puts "Resetting parents at level #{current_level} with #{parent_ids.size} potential parents"
        end
      end
      
      # Insert any remaining nodes
      DB[:nodes].multi_insert(node_batches) unless node_batches.empty?
    end
    
    puts "Node generation completed in #{time.real.round(2)} seconds."
    puts "Re-enabling foreign key constraints..."
    DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;")
    
    # Add birds
    puts "Generating birds..."
    bird_count = (total_nodes * bird_ratio).to_i
    puts "Creating #{bird_count} birds..."
    
    birds_time = Benchmark.measure do
      bird_batches = []
      
      # Get a sample of node IDs for attaching birds
      # For large datasets, we'll get batches to avoid memory issues
      total_inserted = 0
      batch_size = [100_000, bird_count].min
      
      while total_inserted < bird_count
        to_insert = [batch_size, bird_count - total_inserted].min
        
        # Get random nodes
        node_ids = DB[:nodes].select(:id).order(Sequel.lit('RANDOM()')).limit(to_insert).select_map(:id)
        
        bird_data = node_ids.map { |node_id| {node_id: node_id} }
        DB[:birds].multi_insert(bird_data)
        
        total_inserted += to_insert
        puts "Inserted #{total_inserted}/#{bird_count} birds..."
      end
    end
    
    puts "Bird generation completed in #{birds_time.real.round(2)} seconds."
    
    # Print statistics
    puts "Final statistics:"
    puts "Total nodes: #{DB[:nodes].count}"
    puts "Total birds: #{DB[:birds].count}"
    
    # Print tree depth statistics
    puts "\nCalculating tree statistics..."
    stats_time = Benchmark.measure do
      # This CTE finds the depth of each node
      depth_query = <<-SQL
        WITH RECURSIVE node_depth AS (
          SELECT id, parent_id, 1 AS depth
          FROM nodes
          WHERE parent_id IS NULL
          
          UNION ALL
          
          SELECT n.id, n.parent_id, nd.depth + 1
          FROM nodes n
          JOIN node_depth nd ON n.parent_id = nd.id
        )
        SELECT 
          MIN(depth) AS min_depth,
          MAX(depth) AS max_depth,
          AVG(depth) AS avg_depth
        FROM node_depth;
      SQL
      
      result = DB[depth_query].first
      puts "Tree depth: min=#{result[:min_depth]}, max=#{result[:max_depth]}, avg=#{result[:avg_depth].round(2)}"
    end
    
    puts "Statistics calculated in #{stats_time.real.round(2)} seconds."
    
    # Create performance test task that measures endpoint performance
    puts "\nTo test API performance, use: rake test_performance"
  rescue => e
    puts "Error generating data: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

desc 'Generate smaller dataset for performance testing (100K nodes)'
task :small_performance_data do
  ENV['NODES'] = '100000'  # 100K nodes
  Rake::Task["generate_performance_data"].invoke
end

desc 'Generate 10 million nodes with optimized approach'
task :ten_million_nodes do
  require 'benchmark'
  require 'logger'
  
  # Setup logging
  logger = Logger.new(STDOUT)
  logger.level = Logger::INFO
  logger.formatter = proc do |severity, datetime, progname, msg|
    "#{severity}: #{msg}\n"
  end
  
  begin
    # Configuration
    total_nodes = 10_000_000
    batch_size = 500_000
    max_width = 1000  # Wider tree, less depth
    max_children_per_parent = 100  # Increased from 3 to 100
    
    logger.info "Starting node generation for #{total_nodes} nodes"
    logger.info "System resources:"
    logger.info "  Database URL: #{ENV['DATABASE_URL']}"
    logger.info "  Batch size: #{batch_size}"
    logger.info "  Max width: #{max_width}"
    logger.info "  Max children per parent: #{max_children_per_parent}"
    
    # Check database connection
    begin
      DB.test_connection
      logger.info "Database connection successful"
    rescue => e
      logger.error "Database connection failed: #{e.message}"
      raise
    end
    
    logger.info "Clearing existing data..."
    begin
      DB[:birds].delete
      DB[:nodes].delete
      logger.info "Existing data cleared successfully"
    rescue => e
      logger.error "Failed to clear existing data: #{e.message}"
      raise
    end
    
    logger.info "Temporarily disabling foreign key constraints..."
    begin
      DB.run("ALTER TABLE nodes DISABLE TRIGGER ALL;")
      logger.info "Foreign key constraints disabled"
    rescue => e
      logger.error "Failed to disable foreign key constraints: #{e.message}"
      raise
    end
    
    # Configure PostgreSQL for bulk loading
    begin
      logger.info "Configuring PostgreSQL for bulk loading..."
      DB.run("SET maintenance_work_mem = '1GB';")
      DB.run("SET synchronous_commit = 'off';")
      DB.run("SET work_mem = '256MB';")
      logger.info "PostgreSQL configured successfully"
    rescue => e
      logger.error "Failed to configure PostgreSQL: #{e.message}"
      raise
    end
    
    # Start transaction for node generation
    DB.transaction do
      begin
        # Root level
        root_id = 1
        logger.info "Creating root node..."
        DB[:nodes].insert(id: root_id, parent_id: nil)
        
        # Level 1 - Generate a wide array of direct children under root
        logger.info "Generating level 1 nodes (direct children of root)..."
        level1_count = [max_width, total_nodes - 1].min
        level1_batch = []
        
        (2..(level1_count + 1)).each do |id|
          level1_batch << {id: id, parent_id: root_id}
        end
        
        DB[:nodes].multi_insert(level1_batch)
        logger.info "Created #{level1_count} nodes at level 1"
        
        # Level 2+ - Add children to each previous level's nodes
        level = 2
        current_id = level1_count + 2
        remaining = total_nodes - level1_count - 1
        
        while remaining > 0
          logger.info "Generating level #{level} nodes..."
          
          # Get parent IDs from previous level
          previous_level_start = level == 2 ? 2 : current_id - remaining - batch_size
          previous_level_end = level == 2 ? level1_count + 1 : current_id - 1
          
          begin
            parent_ids = DB[:nodes]
              .where(id: previous_level_start..previous_level_end)
              .select_map(:id)
            
            if parent_ids.empty?
              logger.warn "No more parents available at previous level"
              break
            end
            
            level_node_count = 0
            parent_ids.each do |parent_id|
              # Determine children count for this parent
              children_per_parent = [max_children_per_parent, remaining].min
              break if children_per_parent <= 0
              
              # Create batch for this parent
              batch = []
              children_per_parent.times do
                batch << {id: current_id, parent_id: parent_id}
                current_id += 1
                remaining -= 1
                level_node_count += 1
                break if remaining <= 0
              end
              
              begin
                DB[:nodes].multi_insert(batch) unless batch.empty?
              rescue => e
                logger.error "Failed to insert batch at level #{level}: #{e.message}"
                raise
              end
            end
            
            logger.info "Created #{level_node_count} nodes at level #{level}"
            logger.info "Remaining: #{remaining}"
            
            level += 1
          rescue => e
            logger.error "Error at level #{level}: #{e.message}"
            raise
          end
        end
      rescue => e
        logger.error "Transaction failed: #{e.message}"
        raise
      end
    end
    
    # Re-enable foreign key constraints
    logger.info "Re-enabling foreign key constraints..."
    begin
      DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;")
      logger.info "Foreign key constraints re-enabled"
    rescue => e
      logger.error "Failed to re-enable foreign key constraints: #{e.message}"
      raise
    end
    
    # Reset PostgreSQL config
    begin
      DB.run("RESET maintenance_work_mem;")
      DB.run("RESET synchronous_commit;")
      DB.run("RESET work_mem;")
      logger.info "PostgreSQL settings reset"
    rescue => e
      logger.error "Failed to reset PostgreSQL settings: #{e.message}"
      raise
    end
    
    # Create birds (5% of nodes)
    begin
      bird_count = (DB[:nodes].count * 0.05).to_i
      logger.info "Creating #{bird_count} birds..."
      
      batch_size = 500_000
      remaining_birds = bird_count
      
      while remaining_birds > 0
        batch_count = [batch_size, remaining_birds].min
        
        begin
          node_sample = DB[:nodes].select(:id)
            .order(Sequel.lit('RANDOM()'))
            .limit(batch_count)
            .select_map(:id)
          
          bird_batch = node_sample.map { |node_id| {node_id: node_id} }
          DB[:birds].multi_insert(bird_batch)
          
          remaining_birds -= batch_count
          logger.info "Created #{batch_count} birds. Remaining: #{remaining_birds}"
        rescue => e
          logger.error "Failed to create bird batch: #{e.message}"
          raise
        end
      end
    rescue => e
      logger.error "Bird creation failed: #{e.message}"
      raise
    end
    
    # Final stats
    begin
      actual_nodes = DB[:nodes].count
      actual_birds = DB[:birds].count
      db_size = DB['SELECT pg_size_pretty(pg_database_size(current_database())) as size'].first[:size]
      
      logger.info "Final statistics:"
      logger.info "Total nodes: #{actual_nodes}"
      logger.info "Total birds: #{actual_birds}"
      logger.info "Database size: #{db_size}"
      
      if actual_nodes < total_nodes
        logger.warn "Generated fewer nodes than expected (#{actual_nodes} vs #{total_nodes})"
      end
      
      # Report tree structure
      level_counts = DB[<<~SQL].all
        WITH RECURSIVE node_levels AS (
          SELECT id, parent_id, 1 AS level
          FROM nodes
          WHERE parent_id IS NULL
          
          UNION ALL
          
          SELECT n.id, n.parent_id, nl.level + 1
          FROM nodes n
          JOIN node_levels nl ON n.parent_id = nl.id
        )
        SELECT level, COUNT(*) as count
        FROM node_levels
        GROUP BY level
        ORDER BY level
      SQL
      
      logger.info "\nTree structure:"
      level_counts.each do |row|
        logger.info "Level #{row[:level]}: #{row[:count]} nodes"
      end
      
      logger.info "\nReady for performance and stress testing"
    rescue => e
      logger.error "Failed to generate final statistics: #{e.message}"
      raise
    end
    
  rescue => e
    logger.error "Task failed: #{e.message}"
    logger.error e.backtrace.join("\n")
    raise
  end
end 