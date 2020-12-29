# frozen_string_literal: true

desc 'Run application console (pry)'
task :console do
  sh 'pry -r ./init.rb'
end

USERNAME = 'soumyaray'
IMAGE = 'codepraise-clone_report_worker'
VERSION = '0.1.0'

desc 'Build Docker image'
task :worker do
  require_relative './init'
  CodePraise::CloneReportWorker.new.call
end

# Docker tasks
namespace :docker do
  desc 'Build Docker image'
  task :build do
    puts "\nBUILDING WORKER IMAGE"
    sh "docker build --force-rm -t #{USERNAME}/#{IMAGE}:#{VERSION} ."
  end

  desc 'Run the local Docker container as a worker'
  task :run do
    env = ENV['WORKER_ENV'] || 'development'

    puts "\nRUNNING WORKER WITH LOCAL CONTEXT"
    puts " Running in #{env} mode"

    sh 'docker run -e WORKER_ENV -v $(pwd)/config:/worker/config --rm -it ' \
       "#{USERNAME}/#{IMAGE}:#{VERSION}"
  end

  desc 'Remove exited containers'
  task :rm do
    sh 'docker rm -v $(docker ps -a -q -f status=exited)'
  end

  desc 'List all containers, running and exited'
  task :ps do
    sh 'docker ps -a'
  end

  # desc 'Push Docker image to Docker Hub'
  # task :push do
  #   puts "\nPUSHING IMAGE TO DOCKER HUB"
  #   sh "docker push #{USERNAME}/#{IMAGE}:#{VERSION}"
  # end
end

# Heroku container registry tasks
namespace :heroku do
  desc 'Build and Push Docker image to Heroku Container Registry'
  task :push do
    puts "\nBUILDING + PUSHING IMAGE TO HEROKU"
    sh 'heroku container:push worker'
  end

  desc 'Run worker on Heroku'
  task :run do
    puts "\nRUNNING CONTAINER ON HEROKU"
    sh 'heroku run rake worker'
  end
end

namespace :queue do
  task :config do
    require_relative 'config/environment.rb' # load config info
    require 'aws-sdk-sqs'
    @worker = CodePraise::CloneReportWorker
    @config = @worker.config

    @sqs = Aws::SQS::Client.new(
      access_key_id: @config.AWS_ACCESS_KEY_ID,
      secret_access_key: @config.AWS_SECRET_ACCESS_KEY,
      region: @config.AWS_REGION
    )
  end

  desc 'Create SQS queue for Shoryuken'
  task :create => :config do
    puts "Environment: #{ENV['WORKER_ENV'] || 'development'}"
    @sqs.create_queue(queue_name: @config.REPORT_QUEUE)

    q_url = @sqs.get_queue_url(queue_name: @config.REPORT_QUEUE).queue_url
    puts 'Queue created:'
    puts "  Name: #{@config.REPORT_QUEUE}"
    puts "  Region: #{@config.AWS_REGION}"
    puts "  URL: #{q_url}"
  rescue StandardError => error
    puts "Error creating queue: #{error}"
    puts error.backtrace
  end

  desc 'Purge messages in SQS queue for Shoryuken'
  task :purge => :config do
    q_url = @sqs.get_queue_url(queue_name: @config.REPORT_QUEUE).queue_url
    @sqs.purge_queue(queue_url: q_url)
    puts "Queue #{queue_name} purged"
  rescue StandardError => error
    puts "Error purging queue: #{error}"
  end
end
