# Tree Node API

A Sinatra API for hierarchical tree data using PostgreSQL, optimized for large scale.

## Requirements

- Ruby 2.5+
- PostgreSQL 9.6+

OR

- Docker and Docker Compose

## Setup

### Using Docker (Recommended)

The easiest way to set up and run the application is using Docker:

```
docker-compose up
```

This will:

1. Start a PostgreSQL container with optimized settings for tree operations
2. Build and start the API container
3. Run database migrations and seed data
4. Make the API available at http://localhost:4567

### Manual Setup

1. Install dependencies:

```
bundle install
```

2. Create the databases:

```
createdb birds
createdb birds_test
```

3. Run migrations and seed data:

```
rake db:setup
```

4. Run the API:

```
bundle exec rackup -p 4567
```

The API will be available at http://localhost:4567

## API Endpoints

### 1. Find Common Ancestor

```
GET /nodes/:node_a_id/common_ancestors/:node_b_id
```

Returns the root ID, lowest common ancestor ID, and depth of the lowest common ancestor shared by the two nodes.

Example response:

```json
{
  "root_id": 130,
  "lowest_common_ancestor": 125,
  "depth": 2
}
```

### 2. Find Birds

```
GET /birds?node_ids=123,456,789
```

Returns all bird IDs belonging to the specified nodes or their descendant nodes.

Example response:

```json
{
  "bird_ids": [1, 2, 3, 4, 5]
}
```

## Implementation Details

This API uses PostgreSQL's recursive CTEs to efficiently traverse the tree structure. The implementation is optimized for large-scale hierarchies through:

1. Strategic indexing on `parent_id` columns
2. Efficient SQL queries that minimize table scans
3. Connection pooling for concurrent requests
4. Query composition that takes advantage of PostgreSQL's query planner

The database schema uses an adjacency list model where each node references its parent, allowing for a flexible tree structure that can grow to billions of nodes.

## Docker Configuration

The included Docker configuration provides:

1. **PostgreSQL optimization**: Custom PostgreSQL settings tuned specifically for recursive tree traversals and large hierarchies:

   - Higher memory allocation for complex query execution
   - Optimized query planner settings for hierarchical data
   - Improved B-tree index performance
   - Parallel query execution

2. **Development workflow**: The docker-compose setup includes:
   - Volume mapping for real-time code changes
   - Automatic database setup
   - Container restart on failure
