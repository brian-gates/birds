Sequel.migration do
  change do
    create_table(:birds) do
      primary_key :id
      foreign_key :node_id, :nodes, null: false
      
      # Index for efficient bird lookup by node
      index :node_id
    end
  end
end 