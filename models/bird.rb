class Bird < Sequel::Model
  many_to_one :node
  
  # Find all bird IDs that belong to the given node IDs or their descendants
  def self.find_all_in_subtrees(node_ids, limit = nil, offset = nil)
    return [] if node_ids.empty?
    
    # Get all descendant node IDs (including the input nodes) with a reasonable limit
    descendant_ids = Node.find_descendants(node_ids)
    
    # Find all birds belonging to these nodes
    query = Bird.where(node_id: descendant_ids).order(:id)
    
    # Apply pagination if specified
    query = query.limit(limit) if limit
    query = query.offset(offset) if offset
    
    query.select_map(:id)
  end
  
  # Count birds in the given subtrees
  def self.count_in_subtrees(node_ids)
    return 0 if node_ids.empty?
    
    # Get all descendant node IDs with a limit
    descendant_ids = Node.find_descendants(node_ids)
    
    # Count birds
    Bird.where(node_id: descendant_ids).count
  end
end 