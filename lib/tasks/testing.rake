namespace :test do
  desc 'Run all tests'
  task :all do
    sh 'bundle exec rspec'
  end
  
  desc 'Run API endpoint tests'
  task :api do
    sh 'bundle exec rspec spec/requests'
  end
  
  desc 'Run model tests'
  task :models do
    sh 'bundle exec rspec spec/models'
  end
end

desc 'Run all tests (alias for test:all)'
task :test => 'test:all' 