require_relative '../app'

# Clear existing data
DB[:birds].delete
DB[:nodes].delete

# Insert sample nodes based on problem statement
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

# Create some birds
birds_data = [
  { node_id: 130 },
  { node_id: 130 },
  { node_id: 125 },
  { node_id: 125 },
  { node_id: 2820230 },
  { node_id: 4430546 },
  { node_id: 4430546 },
  { node_id: 5497637 },
  { node_id: 5497637 },
  { node_id: 5497637 }
]

birds_data.each do |bird_data|
  DB[:birds].insert(bird_data)
end

puts "Seed data inserted successfully!" 