desc 'Test API performance with timing metrics'
task :test_performance do
  require 'benchmark'
  require 'net/http'
  require 'json'
  require 'uri'
  
  base_url = ENV['API_URL'] || 'http://localhost:4567'
  
  puts "Testing API performance on #{base_url}..."
  
  # Get a few random node ids for testing
  node_count = DB[:nodes].count
  
  if node_count < 100
    puts "Not enough nodes for meaningful performance testing (found #{node_count})"
    exit 1
  end
  
  # Get some nodes at different depths
  sample_nodes = DB[:nodes].select(:id).order(Sequel.lit('RANDOM()')).limit(10).select_map(:id)
  
  # Get some birds
  bird_count = [10, DB[:birds].count].min
  bird_ids = DB[:birds].select(:id, :node_id).order(Sequel.lit('RANDOM()')).limit(bird_count).all
  node_ids_with_birds = bird_ids.map { |b| b[:node_id] }.uniq
  
  puts "\nTesting /nodes/:node_a_id/common_ancestors/:node_b_id endpoint..."
  puts "Testing with #{sample_nodes.size} random node combinations"
  
  common_ancestor_times = []
  
  sample_nodes.combination(2).each do |node_a, node_b|
    url = URI.parse("#{base_url}/nodes/#{node_a}/common_ancestors/#{node_b}")
    
    time = Benchmark.measure do
      response = Net::HTTP.get_response(url)
      if response.code != "200"
        puts "ERROR: #{response.code} - #{response.body[0..100]}"
      end
    end
    
    common_ancestor_times << time.real
    print "."
  end
  
  puts "\nAverage common_ancestors request time: #{(common_ancestor_times.sum / common_ancestor_times.size).round(4)} seconds"
  puts "Min: #{common_ancestor_times.min.round(4)}s, Max: #{common_ancestor_times.max.round(4)}s"
  
  puts "\nTesting /birds endpoint..."
  
  bird_times = []
  
  # Test with 1, 5, and 10 node IDs
  [1, 5, 10].each do |count|
    test_node_ids = node_ids_with_birds.sample([count, node_ids_with_birds.size].min)
    
    next if test_node_ids.empty?
    
    url = URI.parse("#{base_url}/birds?node_ids=#{test_node_ids.join(',')}")
    
    time = Benchmark.measure do
      response = Net::HTTP.get_response(url)
      if response.code != "200"
        puts "ERROR: #{response.code} - #{response.body[0..100]}"
      end
    end
    
    bird_times << time.real
    puts "Request with #{count} node IDs: #{time.real.round(4)} seconds"
  end
  
  puts "\nAverage birds request time: #{(bird_times.sum / bird_times.size).round(4)} seconds"
  puts "Min: #{bird_times.min.round(4)}s, Max: #{bird_times.max.round(4)}s"
end

desc 'Run stress test with concurrent requests'
task :stress_test do
  require 'benchmark'
  require 'net/http'
  require 'uri'
  require 'json'
  require 'concurrent'
  
  # Configuration
  base_url = ENV['API_URL'] || 'http://localhost:4567'
  concurrency = (ENV['CONCURRENCY'] || 10).to_i
  requests_per_thread = (ENV['REQUESTS'] || 100).to_i
  pause_between = (ENV['PAUSE'] || 0.01).to_f
  
  puts "Running stress test with #{concurrency} concurrent clients, #{requests_per_thread} requests each"
  puts "Total requests: #{concurrency * requests_per_thread}"
  
  # Get some random node IDs for testing
  sample_size = [50, DB[:nodes].count].min
  sample_nodes = DB[:nodes].select(:id).order(Sequel.lit('RANDOM()')).limit(sample_size).select_map(:id)
  
  # Get some birds
  bird_sample = [20, DB[:birds].count].min
  bird_ids = DB[:birds].select(:id, :node_id).order(Sequel.lit('RANDOM()')).limit(bird_sample).all
  node_ids_with_birds = bird_ids.map { |b| b[:node_id] }.uniq
  
  # Store results
  common_ancestor_times = Concurrent::Array.new
  birds_times = Concurrent::Array.new
  
  # Create a thread pool
  pool = Concurrent::FixedThreadPool.new(concurrency)
  
  # Submit tasks to the pool
  concurrency.times do |client_id|
    pool.post do
      requests_per_thread.times do |req_num|
        # Alternate between common_ancestors and birds endpoints
        if req_num % 2 == 0
          # Common ancestors request
          node_a, node_b = sample_nodes.sample(2)
          url = URI.parse("#{base_url}/nodes/#{node_a}/common_ancestors/#{node_b}")
          
          time = Benchmark.measure do
            response = Net::HTTP.get_response(url)
            if response.code != "200"
              puts "ERROR [Client #{client_id}]: #{response.code} - #{response.body[0..100]}"
            end
          end
          
          common_ancestor_times << time.real
        else
          # Birds request
          test_node_ids = node_ids_with_birds.sample(rand(1..10))
          url = URI.parse("#{base_url}/birds?node_ids=#{test_node_ids.join(',')}")
          
          time = Benchmark.measure do
            response = Net::HTTP.get_response(url)
            if response.code != "200"
              puts "ERROR [Client #{client_id}]: #{response.code} - #{response.body[0..100]}"
            end
          end
          
          birds_times << time.real
        end
        
        sleep(pause_between) if pause_between > 0
        
        # Periodically report progress
        if (client_id * requests_per_thread + req_num + 1) % 500 == 0
          total_done = common_ancestor_times.size + birds_times.size
          total_expected = concurrency * requests_per_thread
          puts "Progress: #{total_done}/#{total_expected} requests completed (#{(total_done.to_f/total_expected*100).round(1)}%)"
        end
      end
    end
  end
  
  # Wait for all threads to complete
  pool.shutdown
  pool.wait_for_termination
  
  # Analyze results
  total_requests = common_ancestor_times.size + birds_times.size
  
  # Common ancestors stats
  ca_avg = common_ancestor_times.sum / common_ancestor_times.size
  ca_min = common_ancestor_times.min
  ca_max = common_ancestor_times.max
  ca_median = common_ancestor_times.sort[common_ancestor_times.size / 2]
  ca_p95 = common_ancestor_times.sort[(common_ancestor_times.size * 0.95).to_i]
  
  # Birds stats
  birds_avg = birds_times.sum / birds_times.size
  birds_min = birds_times.min
  birds_max = birds_times.max
  birds_median = birds_times.sort[birds_times.size / 2]
  birds_p95 = birds_times.sort[(birds_times.size * 0.95).to_i]
  
  puts "\nStress test complete. #{total_requests} total requests."
  
  puts "\nCommon Ancestors Endpoint:"
  puts "  Requests: #{common_ancestor_times.size}"
  puts "  Average: #{(ca_avg * 1000).round(2)} ms"
  puts "  Median: #{(ca_median * 1000).round(2)} ms"
  puts "  95th percentile: #{(ca_p95 * 1000).round(2)} ms"
  puts "  Min: #{(ca_min * 1000).round(2)} ms"
  puts "  Max: #{(ca_max * 1000).round(2)} ms"
  
  puts "\nBirds Endpoint:"
  puts "  Requests: #{birds_times.size}"
  puts "  Average: #{(birds_avg * 1000).round(2)} ms"
  puts "  Median: #{(birds_median * 1000).round(2)} ms"
  puts "  95th percentile: #{(birds_p95 * 1000).round(2)} ms"
  puts "  Min: #{(birds_min * 1000).round(2)} ms"
  puts "  Max: #{(birds_max * 1000).round(2)} ms"
  
  throughput = total_requests / (common_ancestor_times + birds_times).sum
  puts "\nThroughput: #{throughput.round(2)} requests/second"
end 