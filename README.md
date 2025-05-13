# Birds Challenge

## Overview

This project implements a scalable API for working with tree-structured data using PostgreSQL and Ruby (Sinatra). The solution focuses on optimizing for future growth to potentially billions of nodes while maintaining performance.

## API Endpoints

### 1. Find Common Ancestors

```
GET /nodes/:node_a_id/common_ancestors/:node_b_id
```

Returns the `root_id`, `lowest_common_ancestor`, and `depth` of the lowest common ancestor between two nodes.

Example responses:

- `/nodes/5497637/common_ancestors/2820230` → `{root_id: 130, lowest_common_ancestor: 125, depth: 2}`
- `/nodes/5497637/common_ancestors/130` → `{root_id: 130, lowest_common_ancestor: 130, depth: 1}`
- `/nodes/9/common_ancestors/4430546` → `{root_id: null, lowest_common_ancestor: null, depth: null}`

### 2. Find Birds in Subtrees

```
GET /birds?node_ids=1,2,3
```

Returns IDs of birds that belong to the specified nodes or any of their descendants.

Example:

- `/birds?node_ids=125,130` → `{bird_ids: [1, 2, 3, 4, 5]}`

## Setup Instructions

1. Clone the repository
2. Install Docker and Docker Compose
3. Run setup:

```bash
docker compose up
```

This will:

- Start PostgreSQL database
- Run migrations
- Load sample data
- Start the API server on port 4567

## Technical Approach

### Technology Selection

I selected PostgreSQL for the database and Sinatra for the API framework.

#### Database Selection: PostgreSQL vs Neo4j

I evaluated both PostgreSQL and Neo4j for handling hierarchical tree data. While Neo4j offers native graph capabilities, PostgreSQL was selected because:

1. It provides excellent performance for tree operations using recursive CTEs
2. Has more mature Ruby ecosystem integration
3. Scales effectively to billions of nodes with proper optimization
4. Aligns with the specific requirements in the prompt

For detailed comparison, see [Neo4j vs PostgreSQL Analysis](docs/neoj4-vs-postgres.md).

#### Framework Selection: Sinatra

From the Ruby framework options (Rails, Sinatra, Cuba), I selected Sinatra because:

1. It's lightweight yet powerful for creating focused APIs
2. Offers excellent performance characteristics
3. Provides flexibility without unnecessary overhead
4. Integrates well with Sequel for database operations

For detailed comparison, see [Ruby Framework Comparison](docs/ruby-framework-comparison.md).

### Key Implementation Features

1. **Optimized Database Schema**:

   - Efficient indexing on `parent_id` column
   - Minimal schema design for storage efficiency
   - Explicit foreign key constraints for referential integrity

2. **Efficient Query Patterns**:

   - Recursive Common Table Expressions (CTEs) for tree traversal
   - Optimized ancestor and descendant finding algorithms
   - Query parameter binding for prepared statement caching

3. **Scaling Considerations**:
   - Database connection pooling
   - Minimal data transfer between API and database
   - Focused queries that return only necessary information

## Performance Overview

The system has been tested extensively with datasets ranging from a few nodes to 95+ million nodes with consistent sub-100ms response times across all endpoints.

Key performance highlights:

- PostgreSQL's recursive CTEs provide excellent performance for tree operations
- Consistent response times even as the dataset grows by orders of magnitude
- Effective under concurrent load with multiple simultaneous users

For complete performance metrics, testing methodology, and scaling recommendations, see the [Performance Summary](docs/performance-summary.md) document.

## Code Organization

- `app.rb` - Main Sinatra application with API endpoints
- `models/` - Sequel models for nodes and birds
- `db/migrations/` - Database schema and migrations
- `docs/` - Analysis documentation and performance reports
- `docker-compose.yml` - Containerized development environment
