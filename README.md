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

#### Database Considerations

PostgreSQL works well for handling hierarchical tree data because:

1. It provides excellent performance for tree operations using recursive CTEs
2. Has mature Ruby ecosystem integration
3. Scales effectively to billions of nodes with proper optimization
4. Aligns with the specific requirements in the prompt

#### API Framework

Sinatra provides:

1. Lightweight implementation for focused APIs
2. Excellent performance characteristics
3. Flexibility without unnecessary overhead
4. Solid integration with Sequel for database operations

### Key Implementation Features

1. **Optimized Database Schema**:

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

## Performance

Performance testing with datasets from small to 95+ million nodes shows the solution scales effectively with PostgreSQL's recursive CTEs. Response times remain consistently fast even under concurrent load, with most queries completing in under 100ms.

The provided rake tasks allow performance testing under various conditions:

- `rake test_performance` - Benchmark API response times
- `rake stress_test` - Test behavior under concurrent requests
- `rake stress_capacity` - Monitor resource usage during continuous data growth

## Task Organization

The project uses rake tasks for database management, data import, and performance testing:

```
# Database tasks
rake db:create      # Create database
rake db:migrate     # Run migrations
rake db:reset       # Reset database

# Data import tasks
rake db:import_csv  # Import data from CSV files

# Data generation
rake small_performance_data      # Generate small dataset (~100K nodes)
rake generate_expanded_dataset   # Generate large dataset (10-20M nodes)
rake generate_performance_data   # Generate large dataset for performance testing
rake huge_performance_data       # Generate huge dataset (100M nodes)
rake ten_million_nodes           # Generate 10 million nodes

# Performance testing
rake test_performance            # Run API performance tests with timing metrics
rake stress_test                 # Run stress test with concurrent requests
rake stress_capacity             # Continuously add nodes with resource monitoring

# Testing
rake test               # Run all tests
rake test:api           # Run API endpoint tests
rake test:models        # Run model tests
```

## Testing

The project includes a comprehensive test suite that validates all requirements from the prompt:

- **Common ancestor endpoint tests** verify all specified scenarios
- **Birds endpoint tests** verify finding birds across various node configurations
- **Performance tests** using `rake test_performance` and `rake stress_test` for timing and concurrency metrics

Run tests with:

```
rake test
```

Run performance tests with:

```
rake test_performance
rake stress_test
```

The test suite automatically runs on GitHub Actions for all pull requests and pushes to the main branch, ensuring that code changes meet the requirements and don't introduce regressions.

## Code Organization

- `app.rb` - Main Sinatra application with API endpoints
- `models/` - Sequel models for nodes and birds
- `db/migrations/` - Database schema and migrations
- `lib/tasks/` - Rake tasks for database and data management
- `docs/` - Analysis documentation and performance reports
- `spec/` - Test suite for API endpoints and models
- `docker-compose.yml` - Containerized development environment
