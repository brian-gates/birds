# Birds Challenge

_This project addresses the challenge defined in [PROMPT.md](docs/PROMPT.md)_

[![Test Suite](https://github.com/brian-gates/birds/actions/workflows/test.yml/badge.svg?branch=add-github-actions)](https://github.com/brian-gates/birds/actions/workflows/test.yml)

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

### Technology Stack

This project uses PostgreSQL for the database and Sinatra for the API framework.

#### Database Implementation

The PostgreSQL implementation includes:

1. [Recursive CTEs for efficient tree traversal operations](models/node.rb#L7-L22)
2. [Proper indexing for optimized query performance](db/migrations/001_create_nodes.rb#L6-L8)
3. [Connection pooling for concurrent request handling](db/config.rb#L32-L36)

#### API Framework

Sinatra provides:

1. [Lightweight implementation for focused APIs](app.rb)
2. Excellent performance characteristics
3. Flexibility without unnecessary overhead
4. [Solid integration with Sequel for database operations](models/bird.rb)

### Key Implementation Features

1. **Efficient Query Patterns**:

   - Recursive Common Table Expressions (CTEs) for tree traversal
   - Optimized ancestor and descendant finding algorithms
   - Query parameter binding for prepared statement caching

2. **Scaling Considerations**:
   - Database connection pooling configured with 10 concurrent connections
   - Connection validation with 30-second timeout to handle disconnects
   - Configurable statement timeouts with fallback safety mechanisms
   - Minimal data transfer between API and database
   - Focused queries that return only necessary information

## Performance

Performance testing with datasets from small to 95+ million nodes shows the solution scales effectively with PostgreSQL's recursive CTEs. Response times remain consistently fast even under concurrent load, with most queries completing in under 100ms.

The provided rake tasks allow performance testing under various conditions:

- `rake test_performance` - Benchmark API response times
- `rake stress_test` - Test behavior under concurrent requests
- `rake stress_capacity` - Monitor resource usage during continuous data growth

## Task Organization

The project uses rake tasks for database management and data import:

```
# Database tasks
rake db:migrate     # Run migrations
rake db:reset       # Reset database (migrate, import CSV)

# Data import tasks
rake db:import_csv  # Import data from CSV files

# Testing
rake test               # Run all tests
rake test:api           # Run API endpoint tests
rake test:models        # Run model tests
```

## Testing

The project includes a test suite that validates the API functionality:

- **[Common ancestor endpoint tests](spec/requests/common_ancestors_spec.rb)** verify the lowest common ancestor functionality
- **[Birds endpoint tests](spec/requests/birds_spec.rb)** verify finding birds across specified subtrees

Run tests with:

```
rake test
```

The test suite automatically runs on GitHub Actions for all pull requests and pushes to the main branch, ensuring that code changes meet the requirements and don't introduce regressions.

## Code Organization

- [`app.rb`](app.rb) - Main Sinatra application with API endpoints
- [`models/`](models/) - Sequel models for nodes and birds
- [`db/migrations/`](db/migrations/) - Database schema and migrations
- [`lib/tasks/`](lib/tasks/) - Rake tasks for database and data management
- [`docs/`](docs/) - Project documentation
- [`spec/`](spec/) - Test suite for API endpoints and models
- [`docker-compose.yml`](docker-compose.yml) - Containerized development environment
