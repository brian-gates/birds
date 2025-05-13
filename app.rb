require 'sinatra/base'
require 'sinatra/json'

# Use shared database configuration
require_relative 'db/config'

# Require models
require_relative 'models/node'
require_relative 'models/bird'

class TreeNodeAPI < Sinatra::Base
  # Common Ancestor endpoint
  get '/nodes/:node_a_id/common_ancestors/:node_b_id' do
    node_a_id = params[:node_a_id].to_i
    node_b_id = params[:node_b_id].to_i
    
    result = Node.find_common_ancestor(node_a_id, node_b_id)
    json result
  end
  
  # Birds endpoint with pagination
  get '/birds' do
    node_ids = params[:node_ids].to_s.split(',').map(&:to_i)
    limit = (params[:limit] || 1000).to_i
    offset = (params[:offset] || 0).to_i
    
    # Cap the limit to prevent excessive memory usage
    limit = [limit, 10000].min
    
    begin
      # Use a shorter timeout for the birds endpoint
      with_timeout(10) do
        bird_ids = Bird.find_all_in_subtrees(node_ids, limit, offset)
        total_count = Bird.count_in_subtrees(node_ids)
        
        json({
          bird_ids: bird_ids, 
          total_count: total_count,
          limit: limit,
          offset: offset
        })
      end
    rescue Sequel::DatabaseError => e
      status 500
      json error: "Database error: #{e.message}. Try with different node_ids or a smaller limit."
    end
  end
end 