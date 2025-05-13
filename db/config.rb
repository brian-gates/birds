require 'sequel'
require 'dotenv/load'

# Determine the correct database URL based on the environment
# Try different hosts to support both Docker and local development
db_hosts = ['db', 'localhost']
db_url = ENV['DATABASE_URL']

unless db_url
  # Try each host until one works
  db_hosts.each do |host|
    test_url = "postgres://postgres@#{host}/birds"
    begin
      # Try a quick connection test
      temp_db = Sequel.connect(test_url, connect_timeout: 2, test: true)
      temp_db.disconnect
      db_url = test_url
      puts "Successfully connected to PostgreSQL at #{host}"
      break
    rescue => e
      puts "Could not connect to PostgreSQL at #{host}: #{e.message}"
      next
    end
  end
  
  # Fallback to localhost if no connections worked
  db_url ||= "postgres://localhost/birds"
end

puts "Using database URL: #{db_url}"

# Set up connection options with larger pool
connection_options = {
  max_connections: 10,
  connect_timeout: 15
}

# Central database configuration to be used by both app.rb and Rakefile
begin
  DB = Sequel.connect(db_url, connection_options)
rescue => e
  puts "Error connecting to database: #{e.message}"
  puts "Please ensure PostgreSQL is running and database 'birds' exists."
  puts "You can create it with: createdb birds"
  exit 1
end

# Add connection validation to handle disconnects
DB.extension :connection_validator
DB.pool.connection_validation_timeout = 30

# Set default statement timeout to 60 seconds (increased from 10s)
DB.run("SET statement_timeout = '600s'") rescue nil

# Function to adjust statement timeout for different operations
def with_timeout(seconds)
  DB.run("SET statement_timeout = '#{seconds}s'")
  result = yield
  DB.run("SET statement_timeout = '60s'")
  result
rescue => e
  DB.run("SET statement_timeout = '60s'") rescue nil
  raise e
end

# Log database connection information for debugging
puts "Database configuration: #{DB.opts.select { |k,v| [:adapter, :host, :database, :max_connections].include?(k) }}" 