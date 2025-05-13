require 'sequel'
require 'dotenv/load'

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |t, args|
    Sequel.extension :migration
    db = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/tree_node_api_development')
    
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, 'db/migrations', target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(db, 'db/migrations')
    end
  end
  
  desc 'Rollback migration'
  task :rollback do
    Sequel.extension :migration
    db = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/tree_node_api_development')
    
    current = db[:schema_info].first[:version]
    target = current.to_i - 1
    
    puts "Rolling back from version #{current} to #{target}"
    Sequel::Migrator.run(db, 'db/migrations', target: target)
  end
  
  desc 'Reset database'
  task :reset do
    Sequel.extension :migration
    db = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/tree_node_api_development')
    
    Sequel::Migrator.run(db, 'db/migrations', target: 0)
    Sequel::Migrator.run(db, 'db/migrations')
  end
  
  desc 'Load seed data'
  task :seed do
    puts "Loading seed data..."
    load File.join(File.dirname(__FILE__), 'db', 'seed.rb')
  end
  
  desc 'Setup database (migrate and seed)'
  task setup: [:migrate, :seed]
end 