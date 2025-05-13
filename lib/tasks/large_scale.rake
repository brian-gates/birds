desc 'Generate huge dataset for performance testing (100M nodes)'
task :huge_performance_data do
  require 'benchmark'
  
  # Configuration for huge dataset
  total_nodes = 100_000_000  # 100 million nodes
  batch_size = 100_000       # Larger batch size for faster inserts
  max_children = 5           # Fewer children per node for better breadth
  bird_ratio = 0.01          # Lower bird ratio to avoid overwhelming bird table
  report_interval = 10       # Report progress less frequently
  
  puts "Preparing for massive data generation (#{total_nodes} nodes)..."
  puts "This operation requires significant resources. Ensure your system has enough memory and disk space."
  puts "Estimated disk space needed: ~#{(total_nodes * 20 / 1_000_000).round} GB"
  
  puts "Clearing existing data..."
  DB[:birds].delete
  DB[:nodes].delete
  
  puts "Temporarily disabling foreign key constraints..."
  DB.run("ALTER TABLE nodes DISABLE TRIGGER ALL;")
  
  # Configure PostgreSQL for bulk loading
  DB.run("SET maintenance_work_mem = '1GB';")
  DB.run("SET synchronous_commit = 'off';")
  
  # Create root node
  root_id = 1
  DB[:nodes].insert(id: root_id, parent_id: nil)
  
  puts "Generating #{total_nodes} nodes..."
  
  current_id = 2
  parent_ids = [root_id]
  current_level = 1
  max_depth = 12
  
  # Track progress
  last_report_time = Time.now
  progress_markers = [0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1.0]
  next_marker = 0
  
  node_batches = []
  
  begin
    time = Benchmark.measure do
      # Pre-allocate parent IDs at each level for better distribution
      level_parents = {}
      level_parents[1] = [root_id]
      
      while current_id <= total_nodes && current_level <= max_depth
        level_parents[current_level + 1] = [] unless level_parents[current_level + 1]
        
        # Process current level
        level_parents[current_level].each do |parent_id|
          # Get random number of children (1 to max_children)
          children_count = rand(1..max_children)
          
          children_count.times do
            break if current_id > total_nodes
            
            node_batches << {id: current_id, parent_id: parent_id}
            level_parents[current_level + 1] << current_id
            current_id += 1
            
            # Insert in batches
            if node_batches.size >= batch_size
              DB[:nodes].multi_insert(node_batches)
              node_batches = []
              
              # Progress reporting
              if Time.now - last_report_time > report_interval
                completion = current_id.to_f / total_nodes
                
                # Check if we've hit the next progress marker
                if completion >= progress_markers[next_marker]
                  puts "Progress: #{(completion * 100).round(1)}% - #{current_id} nodes created - Level: #{current_level}"
                  next_marker += 1
                end
                
                last_report_time = Time.now
              end
            end
          end
        end
        
        current_level += 1
        
        # If we run out of parents but haven't reached our node count, 
        # create a new level of parent nodes to continue
        if level_parents[current_level].empty? && current_id <= total_nodes
          puts "Level #{current_level-1} exhausted. Creating new parent level..."
          
          # Create a set of new parent nodes
          new_parents = []
          100.times do |i|
            new_id = current_id
            node_batches << {id: new_id, parent_id: root_id}
            new_parents << new_id
            current_id += 1
          end
          
          # Insert the new parent nodes
          DB[:nodes].multi_insert(node_batches) unless node_batches.empty?
          node_batches = []
          
          level_parents[current_level] = new_parents
        end
      end
      
      # Insert any remaining nodes
      DB[:nodes].multi_insert(node_batches) unless node_batches.empty?
    end
    
    puts "Node generation completed in #{time.real.round(2)} seconds."
    
    # Re-enable foreign key constraints
    puts "Re-enabling foreign key constraints..."
    DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;")
    
    # Reset PostgreSQL config
    DB.run("RESET maintenance_work_mem;")
    DB.run("RESET synchronous_commit;")
    
    # Create a subset of birds (1% of nodes)
    bird_count = (total_nodes * bird_ratio).to_i
    puts "Creating #{bird_count} birds..."
    
    birds_time = Benchmark.measure do
      birds_created = 0
      
      # Process in manageable batches to avoid memory issues
      batch_size = 500_000
      remaining = bird_count
      
      while birds_created < bird_count
        batch_to_create = [batch_size, remaining].min
        
        # Get a random sample of nodes for this batch
        node_sample = DB[:nodes].select(:id)
          .order(Sequel.lit('RANDOM()'))
          .limit(batch_to_create)
          .select_map(:id)
        
        # Create bird records
        bird_batch = node_sample.map { |node_id| {node_id: node_id} }
        DB[:birds].multi_insert(bird_batch)
        
        birds_created += batch_to_create
        remaining -= batch_to_create
        
        puts "Progress: #{birds_created}/#{bird_count} birds created (#{(birds_created.to_f / bird_count * 100).round(1)}%)"
      end
    end
    
    puts "Bird generation completed in #{birds_time.real.round(2)} seconds."
    
    # Final stats
    actual_nodes = DB[:nodes].count
    actual_birds = DB[:birds].count
    
    puts "Final statistics:"
    puts "Total nodes: #{actual_nodes}"
    puts "Total birds: #{actual_birds}"
    
    # Create some sample trees for depth testing
    puts "Generating tree depth statistics (sampling)..."
    sample_size = 1000
    
    stats_time = Benchmark.measure do
      # This samples random paths to estimate tree depth
      depth_query = <<-SQL
        WITH RECURSIVE 
        random_nodes AS (
          SELECT id
          FROM nodes
          WHERE id != 1
          ORDER BY RANDOM()
          LIMIT #{sample_size}
        ),
        node_paths AS (
          SELECT n.id, n.parent_id, 1 AS depth
          FROM nodes n
          JOIN random_nodes r ON n.id = r.id
          
          UNION ALL
          
          SELECT n.id, n.parent_id, p.depth + 1
          FROM nodes n
          JOIN node_paths p ON n.id = p.parent_id
          WHERE n.parent_id IS NOT NULL
        )
        SELECT 
          AVG(max_depth) AS avg_max_depth,
          MIN(max_depth) AS min_max_depth,
          MAX(max_depth) AS max_max_depth
        FROM (
          SELECT id, MAX(depth) AS max_depth
          FROM node_paths
          GROUP BY id
        ) depth_by_node;
      SQL
      
      depth_stats = DB[depth_query].first
      puts "Tree depth statistics (based on #{sample_size} random paths):"
      puts "  Average depth: #{depth_stats[:avg_max_depth].round(1)}"
      puts "  Min depth: #{depth_stats[:min_max_depth]}"
      puts "  Max depth: #{depth_stats[:max_max_depth]}"
    end
    
    puts "Tree statistics calculated in #{stats_time.real.round(2)} seconds."
    puts "Ready for performance testing. Use: rake test_performance"
    
  rescue => e
    puts "Error generating data: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

desc 'Continuously add nodes with resource monitoring until reaching system capacity'
task :stress_capacity do
  require 'benchmark'

  # Configuration
  batch_size = 1_000_000  # Add 1M nodes per batch 
  max_batches = 100       # Safety limit to avoid infinite loop
  target_child_ratio = 3  # Children per parent
  
  puts "Starting capacity stress test - will generate nodes until resources are exhausted"
  puts "Press Ctrl+C at any time to stop the test"
  
  # Clear existing data first
  puts "Clearing existing data..."
  DB[:birds].delete
  DB[:nodes].delete
  
  # Disable constraints for faster processing
  puts "Optimizing database for bulk loading..."
  DB.run("ALTER TABLE nodes DISABLE TRIGGER ALL;")
  DB.run("SET maintenance_work_mem = '1GB';")
  DB.run("SET synchronous_commit = 'off';")
  
  # Create root node
  root_id = 1
  DB[:nodes].insert(id: root_id, parent_id: nil)
  puts "Created root node"
  
  # Prepare second level nodes (direct children of root)
  second_level_count = 1000
  level1_batch = []
  (2..(second_level_count + 1)).each do |id|
    level1_batch << {id: id, parent_id: root_id}
  end
  DB[:nodes].multi_insert(level1_batch)
  puts "Created #{second_level_count} nodes at level 1"
  
  # Track key metrics
  current_id = second_level_count + 2
  last_report_time = Time.now
  report_interval = 30  # seconds
  batches_completed = 0
  total_nodes = second_level_count + 1  # Root + level 1
  
  # Track how big the tree gets at each level
  level = 2
  available_parents = (2..(second_level_count + 1)).to_a
  
  begin
    puts "Starting iterative node generation..."
    
    while batches_completed < max_batches
      puts "Batch #{batches_completed + 1}: Adding up to #{batch_size} nodes at level #{level}..."
      
      batch_time = Benchmark.measure do
        nodes_added = 0
        node_batches = []
        
        # Shuffle parents for more balanced distribution
        available_parents.shuffle!
        
        # Calculate children per parent to reach batch_size
        children_per_parent = [target_child_ratio, (batch_size.to_f / available_parents.size).ceil].min
        new_parents = []
        
        available_parents.each do |parent_id|
          break if nodes_added >= batch_size
          
          # Create children for this parent
          parent_batch = []
          children_per_parent.times do
            break if nodes_added >= batch_size
            
            parent_batch << {id: current_id, parent_id: parent_id}
            new_parents << current_id
            current_id += 1
            nodes_added += 1
          end
          
          # Add this parent's children to the overall batch
          node_batches.concat(parent_batch)
          
          # Insert in batches of 100k for memory efficiency
          if node_batches.size >= 100_000
            DB[:nodes].multi_insert(node_batches)
            node_batches = []
          end
        end
        
        # Insert any remaining nodes
        DB[:nodes].multi_insert(node_batches) unless node_batches.empty?
        
        # Update metrics
        batches_completed += 1
        total_nodes += nodes_added
        
        # Set up for next level
        available_parents = new_parents
        level += 1
      end
      
      # Measure resource usage and performance after each batch
      if Time.now - last_report_time >= report_interval || batches_completed == 1
        # Get database size
        db_size = DB['SELECT pg_size_pretty(pg_database_size(current_database())) as size'].first[:size]
        db_size_bytes = DB['SELECT pg_database_size(current_database()) as size'].first[:size]
        
        # Get current stats
        current_node_count = DB[:nodes].count
        
        # Measure query performance on current dataset
        ca_time = Benchmark.measure do
          # Random node IDs for common ancestor query
          node_a, node_b = DB[:nodes].select(:id).where(Sequel.lit("id > 1")).order(Sequel.lit('RANDOM()')).limit(2).select_map(:id)
          result = DB[<<~SQL].first
            WITH RECURSIVE
            ancestors_a AS (
              SELECT id, parent_id, 1 AS depth
              FROM nodes WHERE id = #{node_a}
              UNION ALL
              SELECT n.id, n.parent_id, a.depth + 1
              FROM nodes n JOIN ancestors_a a ON n.id = a.parent_id
            ),
            ancestors_b AS (
              SELECT id, parent_id, 1 AS depth
              FROM nodes WHERE id = #{node_b}
              UNION ALL
              SELECT n.id, n.parent_id, b.depth + 1
              FROM nodes n JOIN ancestors_b b ON n.id = b.parent_id
            )
            SELECT a.id AS common_ancestor, a.depth
            FROM ancestors_a a JOIN ancestors_b b ON a.id = b.id
            ORDER BY a.depth + b.depth DESC
            LIMIT 1;
          SQL
        end
        
        # Get table and index sizes directly
        table_index_sizes = DB[<<~SQL].all
          SELECT 
            relname as relation,
            pg_size_pretty(pg_total_relation_size(c.oid)) as total_size,
            pg_size_pretty(pg_relation_size(c.oid)) as table_size,
            pg_size_pretty(pg_total_relation_size(c.oid) - pg_relation_size(c.oid)) as index_size
          FROM pg_class c
          LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE relkind = 'r' AND relname IN ('nodes', 'birds')
          ORDER BY pg_total_relation_size(c.oid) DESC;
        SQL
        
        # Get distribution of nodes per level (sample-based for large trees)
        level_distribution = if current_node_count > 1_000_000
          # For large trees, just show a summary without recursive query
          [
            {level: "estimated levels", count: level - 1},
            {level: "total nodes", count: current_node_count}
          ]
        else
          # For smaller trees, get actual distribution
          DB[<<~SQL].all
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
        end
        
        # Print status report
        puts "\n===== STATUS REPORT: BATCH #{batches_completed} =====>"
        puts "Time to generate batch: #{batch_time.real.round(2)} seconds"
        puts "Total nodes: #{current_node_count.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')}"
        puts "Database size: #{db_size} (#{(db_size_bytes.to_f / (1024*1024)).round(2)} MB)"
        puts "Memory per node: #{(db_size_bytes.to_f / current_node_count).round(2)} bytes"
        puts "Common ancestor query time: #{(ca_time.real * 1000).round(2)} ms"
        
        puts "\nTable and index sizes:"
        table_index_sizes.each do |row|
          puts "  #{row[:relation]}: Total #{row[:total_size]} (Table: #{row[:table_size]}, Index: #{row[:index_size]})"
        end
        
        puts "\nNode distribution:"
        if current_node_count <= 1_000_000
          level_distribution.each do |row|
            puts "  Level #{row[:level]}: #{row[:count].to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')} nodes"
          end
        else
          puts "  Estimated tree depth: #{level - 1} levels"
          puts "  Total nodes: #{current_node_count.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')}"
        end
        
        puts "\nContinuing to next batch...\n"
        last_report_time = Time.now
      end
      
      # Break if we've exhausted available parents
      if available_parents.empty?
        puts "No more parents available - tree generation complete"
        break
      end
    end
    
    # Re-enable constraints
    puts "Re-enabling database constraints..."
    DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;")
    DB.run("RESET maintenance_work_mem;")
    DB.run("RESET synchronous_commit;")
    
    # Final counts and performance test
    total_nodes = DB[:nodes].count
    puts "\n===== FINAL RESULTS =====>"
    puts "Total nodes generated: #{total_nodes.to_s.gsub(/(\d)(?=(\d{3})+$)/, '\1,')}"
    puts "Maximum tree depth: #{level - 1}"
    puts "Database size: #{DB['SELECT pg_size_pretty(pg_database_size(current_database())) as size'].first[:size]}"
    
    puts "\nRunning performance test on final dataset..."
    Rake::Task["test_performance"].invoke
    
  rescue => e
    puts "\n===== ERROR: CAPACITY LIMIT REACHED =====>"
    puts "Error: #{e.message}"
    puts "Generation stopped at #{total_nodes} nodes"
    puts e.backtrace.join("\n")
    
    # Try to cleanup
    begin
      DB.run("ALTER TABLE nodes ENABLE TRIGGER ALL;") rescue nil
      DB.run("RESET maintenance_work_mem;") rescue nil
      DB.run("RESET synchronous_commit;") rescue nil
    rescue
      # Ignore cleanup errors
    end
  end
end

desc 'Generate expanded dataset (10-20M nodes) for testing'
task :generate_expanded_dataset do
  require 'benchmark'
  
  # Configuration
  target_nodes = 10_000_000  # Target 10 million nodes
  batch_size = 1_000_000     # Very large batches for faster insertion
  
  # Skip clearing existing data as it's causing timeouts
  puts "Checking existing data..."
  existing_nodes = DB[:nodes].count
  puts "Found #{existing_nodes} existing nodes"
  
  # Configure PostgreSQL for bulk loading
  DB.run("SET statement_timeout = '1800s';")  # 30 minutes timeout for this task
  DB.run("SET maintenance_work_mem = '2GB';")
  DB.run("SET synchronous_commit = 'off';")
  DB.run("SET work_mem = '128MB';")
  
  if existing_nodes > 0
    puts "WARNING: Adding to existing data instead of clearing due to timeout risks"
    # Get the maximum existing ID to ensure we don't create duplicates
    max_id = DB[:nodes].max(:id) || 1
    current_id = max_id + 1
    total_created = existing_nodes
    
    # Get root node
    root_id = DB[:nodes].where(parent_id: nil).first[:id] rescue 1
  else
    puts "No existing nodes found, starting fresh"
    # Create root node
    root_id = 1
    DB[:nodes].insert(id: root_id, parent_id: nil)
    puts "Created root node (id=1)"
    current_id = 2
    total_created = 1
  end
  
  # Use a more efficient approach - generate nodes in large batches by level
  levels = 6   # Limit to 6 levels for reasonable depth
  width_per_level = {
    1 => 1_000,     # Level 1: 1,000 nodes under root
    2 => 10,        # Level 2: Each L1 node gets 10 children (10K nodes)
    3 => 20,        # Level 3: Each L2 node gets 20 children (200K nodes) 
    4 => 25,        # Level 4: Each L3 node gets 25 children (5M nodes)
    5 => 5,         # Level 5: Each L4 node gets 5 children (25M nodes)
    6 => 2          # Level 6: Each L5 node gets 2 children (50M nodes)
  }
  
  # Level by level generation
  parent_ids_by_level = { 0 => [root_id] }
  
  (1..levels).each do |level|
    break if total_created >= target_nodes
    
    width = width_per_level[level]
    previous_level = level - 1
    
    # Get parent IDs from previous level
    if parent_ids_by_level[previous_level]
      parent_ids = parent_ids_by_level[previous_level]
    else
      # Fallback to getting recent parent IDs
      parent_ids = DB[:nodes].order(Sequel.desc(:id)).limit(1000).select_map(:id)
    end
    
    puts "Creating level #{level} nodes (width=#{width}, parents=#{parent_ids.size})..."
    new_level_ids = []
    
    # For each parent, create 'width' children
    nodes_in_batch = 0
    batch = []
    
    parent_ids.each do |parent_id|
      remaining = target_nodes - total_created
      break if remaining <= 0
      
      # Determine how many children to create for this parent
      children_to_create = [width, remaining].min
      
      children_to_create.times do
        batch << {id: current_id, parent_id: parent_id}
        new_level_ids << current_id
        current_id += 1
        nodes_in_batch += 1
        
        # Insert in large batches for efficiency
        if nodes_in_batch >= batch_size
          DB[:nodes].multi_insert(batch)
          total_created += nodes_in_batch
          puts "  Created batch of #{nodes_in_batch} nodes (total: #{total_created})"
          batch = []
          nodes_in_batch = 0
        end
      end
    end
    
    # Insert any remaining nodes in the batch
    if nodes_in_batch > 0
      DB[:nodes].multi_insert(batch)
      total_created += nodes_in_batch
      puts "  Created final batch of #{nodes_in_batch} nodes (total: #{total_created})"
    end
    
    parent_ids_by_level[level] = new_level_ids
    puts "Completed level #{level}: #{new_level_ids.size} nodes"
    
    # Stop if we've reached the target
    if total_created >= target_nodes
      puts "Reached target node count (#{total_created}), stopping generation"
      break
    end
  end
  
  # Reset PostgreSQL config
  DB.run("RESET maintenance_work_mem;")
  DB.run("RESET synchronous_commit;")
  DB.run("RESET work_mem;")
  DB.run("RESET statement_timeout;")
  
  # Create birds (0.5% of nodes to keep bird count manageable)
  total_nodes = DB[:nodes].count
  bird_ratio = 0.005  # 0.5%
  bird_count = (total_nodes * bird_ratio).to_i
  puts "Creating #{bird_count} birds (#{bird_ratio*100}% of nodes)..."
  
  birds_created = 0
  batch_size = 100_000
  
  while birds_created < bird_count
    batch_count = [batch_size, bird_count - birds_created].min
    
    # Get random nodes for this batch
    node_sample = DB[:nodes].select(:id)
      .order(Sequel.lit('RANDOM()'))
      .limit(batch_count)
      .select_map(:id)
    
    bird_batch = node_sample.map { |node_id| {node_id: node_id} }
    DB[:birds].multi_insert(bird_batch)
    
    birds_created += batch_count
    puts "Created #{birds_created}/#{bird_count} birds (#{(birds_created.to_f/bird_count*100).round(1)}%)"
  end
  
  # Final stats
  actual_nodes = DB[:nodes].count
  actual_birds = DB[:birds].count
  
  puts "Final statistics:"
  puts "Total nodes: #{actual_nodes}"
  puts "Total birds: #{actual_birds}"
  
  # Calculate tree depth statistics
  puts "Calculating tree depth statistics (sampling)..."
  depth_query = <<-SQL
    WITH RECURSIVE sample_paths AS (
      SELECT n.id, n.parent_id, 1 AS depth
      FROM nodes n
      WHERE n.id IN (
        SELECT id FROM nodes WHERE id != 1 ORDER BY RANDOM() LIMIT 1000
      )
      
      UNION ALL
      
      SELECT p.id, n.parent_id, p.depth + 1
      FROM sample_paths p
      JOIN nodes n ON p.parent_id = n.id
      WHERE n.parent_id IS NOT NULL
    )
    SELECT 
      MAX(depth) AS max_depth,
      MIN(depth) AS min_depth,
      AVG(depth) AS avg_depth
    FROM (
      SELECT id, MAX(depth) AS depth
      FROM sample_paths
      GROUP BY id
    ) AS path_depths
  SQL
  
  begin
    depth_stats = DB[depth_query].first
    puts "Tree depth: min=#{depth_stats[:min_depth]}, max=#{depth_stats[:max_depth]}, avg=#{depth_stats[:avg_depth].round(1)}"
  rescue => e
    puts "Error calculating tree depth: #{e.message}"
  end
  
  puts "Database size: #{DB['SELECT pg_size_pretty(pg_database_size(current_database())) as size'].first[:size]}"
  puts "Ready for performance testing. Run: rake test_performance"
end 