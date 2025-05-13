require 'spec_helper'

describe 'Common Ancestors API' do
  before(:all) do
    # Set up test data as specified in PROMPT.md
    DB[:nodes].delete
    data = [
      { id: 130, parent_id: nil },
      { id: 125, parent_id: 130 },
      { id: 2820230, parent_id: 125 },
      { id: 4430546, parent_id: 125 },
      { id: 5497637, parent_id: 4430546 },
      { id: 9, parent_id: nil } # Separate tree for testing no common ancestor
    ]
    DB[:nodes].multi_insert(data)
  end

  after(:all) do
    DB[:nodes].delete
  end

  describe 'GET /nodes/:node_a_id/common_ancestors/:node_b_id' do
    it 'returns the correct common ancestor info for nodes with a common ancestor' do
      get '/nodes/5497637/common_ancestors/2820230'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['root_id']).to eq(130)
      expect(json_response['lowest_common_ancestor']).to eq(125)
      expect(json_response['depth']).to eq(3)
    end
    
    it 'returns the correct info when one node is an ancestor of the other' do
      get '/nodes/5497637/common_ancestors/130'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['root_id']).to eq(130)
      expect(json_response['lowest_common_ancestor']).to eq(130)
      expect(json_response['depth']).to eq(4)
    end
    
    it 'returns the correct info when one node is the direct parent of the other' do
      get '/nodes/5497637/common_ancestors/4430546'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['root_id']).to eq(130)
      expect(json_response['lowest_common_ancestor']).to eq(4430546)
      expect(json_response['depth']).to eq(2)
    end
    
    it 'returns null for all fields when there is no common ancestor' do
      get '/nodes/9/common_ancestors/4430546'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['root_id']).to be_nil
      expect(json_response['lowest_common_ancestor']).to be_nil
      expect(json_response['depth']).to be_nil
    end
    
    it 'returns the node itself when both node IDs are the same' do
      get '/nodes/4430546/common_ancestors/4430546'
      
      expect(last_response).to be_ok
      json_response = JSON.parse(last_response.body)
      
      expect(json_response['root_id']).to eq(130)
      expect(json_response['lowest_common_ancestor']).to eq(4430546)
      expect(json_response['depth']).to eq(3)
    end
  end
end 