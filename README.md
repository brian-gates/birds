# Birds Challenge

_This project addresses the challenge defined in [PROMPT.md](docs/PROMPT.md)_

## Overview

This project implements a scalable API for working with tree-structured data using PostgreSQL and Ruby (Sinatra). The solution focuses on optimizing for future growth to potentially billions of nodes while maintaining performance.

## API Endpoints

The API implements all requirements specified in the [PROMPT.md](docs/PROMPT.md):

1. Common Ancestors endpoint to find lowest common ancestors between nodes
2. Birds endpoint to find birds in specified subtrees

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
   - Database connection pooling configured with 10 concurrent connections
   - Connection validation with 30-second timeout to handle disconnects
   - Configurable statement timeouts with fallback safety mechanisms
   - Minimal data transfer between API and database
   - Focused queries that return only necessary information

## Performance Overview

The system has been tested extensively with datasets ranging from a few nodes to 95+ million nodes with consistent sub-100ms response times across all endpoints.

Key performance highlights:

- PostgreSQL's recursive CTEs provide excellent performance for tree operations
- Consistent response times even as the dataset grows by orders of magnitude
- Effective under concurrent load with multiple simultaneous users

For complete performance metrics, testing methodology, and scaling recommendations, see the [Performance Summary](docs/performance-summary.md) document.

## Task Organization

The project uses rake tasks for database management, data import, and performance testing:

```bash
# Database tasks
rake db:create      # Create database
rake db:migrate     # Run migrations
rake db:reset       # Reset database

# Data import tasks
rake import:csv     # Import data from CSV files

# Performance testing
rake performance:test:api      # Run API performance tests
rake performance:test:queries  # Test database query performance

# Data generation
rake data:generate       # Generate test datasets
rake data:large_scale    # Generate large-scale data for stress testing

# Testing
rake test               # Run all tests
rake test:api           # Run API endpoint tests
rake test:models        # Run model tests
```

## Testing

The project includes a comprehensive test suite that validates all requirements from the prompt:

- **Common ancestor endpoint tests** verify all specified scenarios
- **Birds endpoint tests** verify finding birds across various node configurations

Run tests with:

```bash
rake test
```

## Code Organization

- `app.rb` - Main Sinatra application with API endpoints
- `models/` - Sequel models for nodes and birds
- `db/migrations/` - Database schema and migrations
- `lib/tasks/` - Rake tasks for database and data management
- `docs/` - Analysis documentation and performance reports
- `spec/` - Test suite for API endpoints and models
- `docker-compose.yml` - Containerized development environment
