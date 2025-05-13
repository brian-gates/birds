require 'sinatra/base'
require 'sinatra/json'
require 'sequel'
require 'dotenv/load'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/birds')

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
  
  # Birds endpoint
  get '/birds' do
    node_ids = params[:node_ids].to_s.split(',').map(&:to_i)
    
    bird_ids = Bird.find_all_in_subtrees(node_ids)
    json bird_ids: bird_ids
  end
end 