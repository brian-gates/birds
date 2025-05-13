class Node < Sequel::Model
  one_to_many :children, class: self, key: :parent_id
  many_to_one :parent, class: self
  one_to_many :birds
  
  # Find all ancestors for a node including itself
  # Returns array of [id, parent_id, depth] arrays
  def self.find_ancestors(node_id)
    DB.fetch(<<-SQL, node_id).all
      WITH RECURSIVE ancestors AS (
        SELECT id, parent_id, 1 AS depth
        FROM nodes
        WHERE id = ?
        
        UNION ALL
        
        SELECT n.id, n.parent_id, a.depth + 1
        FROM nodes n
        JOIN ancestors a ON n.id = a.parent_id
      )
      SELECT id, parent_id, depth FROM ancestors
    SQL
  end
  
  # Find the root node ID for a given node
  def self.find_root(node_id)
    ancestors = find_ancestors(node_id)
    # The last ancestor has no parent (parent_id is nil) and is the root
    root = ancestors.find { |a| a[:parent_id].nil? }
    root ? root[:id] : nil
  end
  
  # Find lowest common ancestor between two nodes
  def self.find_common_ancestor(node_a_id, node_b_id)
    # If nodes are the same, return the node itself
    if node_a_id == node_b_id
      node = DB[:nodes].where(id: node_a_id).first
      if node
        depth = calculate_depth(node_a_id)
        root_id = find_root(node_a_id)
        return { root_id: root_id, lowest_common_ancestor: node_a_id, depth: depth }
      else
        return { root_id: nil, lowest_common_ancestor: nil, depth: nil }
      end
    end
    
    # Get ancestors for both nodes
    ancestors_a = find_ancestors(node_a_id)
    ancestors_b = find_ancestors(node_b_id)
    
    # If either node doesn't exist, return nil for all fields
    if ancestors_a.empty? || ancestors_b.empty?
      return { root_id: nil, lowest_common_ancestor: nil, depth: nil }
    end
    
    # Check if one node is a direct ancestor of the other
    if ancestors_a.any? { |a| a[:id] == node_b_id }
      # node_b is an ancestor of node_a
      depth = ancestors_a.find { |a| a[:id] == node_b_id }[:depth]
      root_id = find_root(node_b_id)
      return { root_id: root_id, lowest_common_ancestor: node_b_id, depth: depth }
    elsif ancestors_b.any? { |b| b[:id] == node_a_id }
      # node_a is an ancestor of node_b
      depth = ancestors_b.find { |b| b[:id] == node_a_id }[:depth]
      root_id = find_root(node_a_id)
      return { root_id: root_id, lowest_common_ancestor: node_a_id, depth: depth }
    end
    
    # Find common ancestors
    common_ancestors = ancestors_a.select { |a| ancestors_b.any? { |b| b[:id] == a[:id] } }
    
    # If no common ancestors, return nil for all fields
    if common_ancestors.empty?
      return { root_id: nil, lowest_common_ancestor: nil, depth: nil }
    end
    
    # Find the lowest common ancestor (the one with the lowest depth)
    lowest = common_ancestors.min_by { |a| a[:depth] }
    
    # Return result
    {
      root_id: find_root(lowest[:id]),
      lowest_common_ancestor: lowest[:id],
      depth: lowest[:depth]
    }
  end
  
  # Calculate depth of a node (distance from root)
  def self.calculate_depth(node_id)
    ancestors = find_ancestors(node_id)
    ancestors.empty? ? nil : ancestors.last[:depth]
  end
  
  # Find all descendant nodes (including self)
  def self.find_descendants(node_ids, limit = 10000)
    return [] if node_ids.empty?
    
    DB.fetch(<<-SQL, node_ids, limit).map(:id)
      WITH RECURSIVE descendants AS (
        -- Base case: the nodes we start with
        SELECT id, parent_id, 0 AS depth
        FROM nodes
        WHERE id IN ?
        
        UNION ALL
        
        -- Recursive case: add children, with a depth limit to prevent infinite recursion
        SELECT n.id, n.parent_id, d.depth + 1
        FROM nodes n
        JOIN descendants d ON n.parent_id = d.id
        WHERE d.depth < 100  -- Add a safety depth limit
      )
      SELECT id FROM descendants
      LIMIT ?  -- Add a limit to prevent excessive memory usage
    SQL
  end
end 