ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'rspec'
require 'database_cleaner/sequel'
require 'sequel'

# Load the application
require_relative '../app'
require_relative '../db/config'

module RSpecMixin
  include Rack::Test::Methods
  def app
    TreeNodeAPI
  end
end

RSpec.configure do |config|
  config.include RSpecMixin
  
  config.before(:suite) do
    DatabaseCleaner[:sequel].strategy = :transaction
    DatabaseCleaner[:sequel].db = DB
  end

  config.before(:each) do
    DatabaseCleaner[:sequel].start
  end

  config.after(:each) do
    DatabaseCleaner[:sequel].clean
  end
end 