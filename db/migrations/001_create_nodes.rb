Sequel.migration do
  change do
    create_table(:nodes) do
      primary_key :id
      foreign_key :parent_id, :nodes, null: true
      
      # Indexing for tree traversal performance
      index :parent_id
    end
  end
end 