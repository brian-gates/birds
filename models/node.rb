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
    
    # Use SQL to efficiently find the common ancestor
    result = DB.fetch(<<-SQL, node_a_id, node_b_id).first
      WITH RECURSIVE
        ancestors_a AS (
          SELECT id, parent_id, 1 AS depth
          FROM nodes
          WHERE id = ?
          
          UNION ALL
          
          SELECT n.id, n.parent_id, a.depth + 1
          FROM nodes n
          JOIN ancestors_a a ON n.id = a.parent_id
        ),
        ancestors_b AS (
          SELECT id, parent_id, 1 AS depth
          FROM nodes
          WHERE id = ?
          
          UNION ALL
          
          SELECT n.id, n.parent_id, b.depth + 1
          FROM nodes n
          JOIN ancestors_b b ON n.id = b.parent_id
        ),
        common_ancestors AS (
          SELECT a.id, a.depth
          FROM ancestors_a a
          JOIN ancestors_b b ON a.id = b.id
        )
        SELECT id, depth
        FROM common_ancestors
        ORDER BY depth DESC
        LIMIT 1
    SQL
    
    if result
      root_id = find_root(result[:id])
      { root_id: root_id, lowest_common_ancestor: result[:id], depth: result[:depth] }
    else
      { root_id: nil, lowest_common_ancestor: nil, depth: nil }
    end
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