# frozen_string_literal: true

require_relative '../../init.rb'
require 'aws-sdk-sqs'

module CodePraise
  # Scheduled worker to report on recent cloning operations
  class CloneReportWorker
    def initialize
      @config = CloneReportWorker.config
      @queue = CodePraise::Messaging::Queue.new(
        @config.REPORT_QUEUE_URL, @config
      )
    end

    def call
      puts "REPORT DateTime: #{Time.now}"

      # Notify administrator of unique clones
      if cloned_projects.any?
        # TODO: Email administrator instead of printing to STDOUT
        puts "\tNumber of unique repos cloned: #{cloned_projects.count}"
        puts "\tTotal disk space: #{total_size}"
      else
        puts "\tNo cloning reported in this period"
      end
    end

    def cloned_projects
      return @cloned_projects if @cloned_projects

      @cloned_projects = {}
      @queue.poll do |clone_request_json|
        clone_request = Representer::CloneRequest
          .new(OpenStruct.new)
          .from_json(clone_request_json)
        @cloned_projects[clone_request.project.origin_id] = clone_request.project
        print '.'
      end

      @cloned_projects.tap { puts }
    end

    def total_size
      cloned_projects.values.reduce(0) { |size, project| size + project.size }
    end
  end
end
