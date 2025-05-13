require 'spec_helper'

describe 'Birds API' do
  before(:all) do
    # Set up test data
    DB[:nodes].delete
    DB[:birds].delete

    # Create node hierarchy
    nodes_data = [
      { id: 130, parent_id: nil },     # Root
      { id: 125, parent_id: 130 },     # Child of root
      { id: 120, parent_id: 130 },     # Another child of root
      { id: 110, parent_id: 125 },     # Grandchild
      { id: 100, parent_id: 125 },     # Another grandchild
      { id: 90, parent_id: 120 },      # Grandchild in different branch
      { id: 9, parent_id: nil }        # Separate tree
    ]
    DB[:nodes].multi_insert(nodes_data)

    # Assign birds to nodes
    birds_data = [
      { id: 1, node_id: 130 },  # Bird on root
      { id: 2, node_id: 125 },  # Bird on child
      { id: 3, node_id: 110 },  # Bird on grandchild
      { id: 4, node_id: 100 },  # Bird on another grandchild
      { id: 5, node_id: 90 },   # Bird on grandchild in different branch
      { id: 6, node_id: 9 }     # Bird on separate tree
    ]
    DB[:birds].multi_insert(birds_data)
  end

  after(:all) do
    DB[:birds].delete
    DB[:nodes].delete
  end

  describe 'GET /birds' do
    it 'returns birds for a single node and its descendants' do
      get '/birds?node_ids=125'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      # Should include birds with IDs 2, 3, and 4 (node 125 and its descendants)
      expect(json_response['bird_ids']).to match_array([2, 3, 4])
    end
    
    it 'returns birds for multiple nodes and their descendants' do
      get '/birds?node_ids=125,120'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      # Should include birds with IDs 2, 3, 4, and 5
      expect(json_response['bird_ids']).to match_array([2, 3, 4, 5])
    end
    
    it 'returns birds for the root node and all its descendants' do
      get '/birds?node_ids=130'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      # Should include all birds except the one in the separate tree
      expect(json_response['bird_ids']).to match_array([1, 2, 3, 4, 5])
    end
    
    it 'returns birds for nodes in separate trees' do
      get '/birds?node_ids=125,9'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      # Should include birds with IDs 2, 3, 4 (from node 125 tree) and 6 (from separate tree)
      expect(json_response['bird_ids']).to match_array([2, 3, 4, 6])
    end
    
    it 'returns an empty array when no birds are found' do
      # Create a node with no birds
      DB[:nodes].insert(id: 1000, parent_id: nil)
      
      get '/birds?node_ids=1000'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['bird_ids']).to eq([])
      
      # Clean up
      DB[:nodes].where(id: 1000).delete
    end
  end
end 