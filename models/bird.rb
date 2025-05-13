class Bird < Sequel::Model
  many_to_one :node
  
  # Find all bird IDs that belong to the given node IDs or their descendants
  def self.find_all_in_subtrees(node_ids)
    return [] if node_ids.empty?
    
    # Get all descendant node IDs (including the input nodes)
    descendant_ids = Node.find_descendants(node_ids)
    
    # Find all birds belonging to these nodes
    Bird.where(node_id: descendant_ids).select_map(:id)
  end
end 