# frozen_string_literal: true

require_relative '../../init.rb'
require_relative '../domain/restaurants/init'
require 'aws-sdk-sqs'

module Ewa
  # Scheduled worker to update new infomartion about a restaurant
  # When user clicks of one restaurant exceed a limit will triggered the update
  # Run every day
  class ClickWorker
    def initialize
      @config = ClickWorker.config
      @queue = Ewa::Messaging::Queue.new(
        @config.CLICK_QUEUE_URL, @config
      )
    end

    def call
      puts "UPDATE RESTAURANT INFO DateTime: #{Time.now}"

      # Update restaurant infos
      rests = update_restaurants

      if rests.any?
        puts "\tNumber of restaurants need update: #{rests.count}"

        rests.keys.each do |rest_id|
          rest_id = rest_id.to_s

          # get rest entity
          rest_entity = Repository::RestaurantDetails.find_by_rest_id(rest_id)
          # get rebuilt repo entity
          # here will auto update click數量
          # update(entity, first_time_or_not)
          rest_detail_entity = RestaurantDetailMapper.new(rest_entity, @config.GMAP_TOKEN).gmap_place_details
          # update cover_pictures as well
          trim_name = rest_detail_entity.name.gsub(' ', '')
          cover_pics = CoverPictureMapper.new(@config.GMAP_TOKEN, @config.CX, trim_name).cover_picture_lists
          new_cover_pic_entities = CoverPictureMapper::BuildCoverPictureEntity.new(cover_pics).build_entity
          cov_pic_repo_entities = Repository::CoverPictures.db_update(new_cover_pic_entities, rest_detail_entity.id)
          # update restaurant
          repo_entity = Repository::RestaurantDetails.update(rest_detail_entity, false)
          puts "\tUpdate #{rest_id} ready."
        end
      else
        puts "\tNo update restaurants need for today."
      end
    end

    def update_restaurants
      return @updated_restaurants if @updated_restaurants

      @updated_restaurants = {}
      queues = @queue.poll

      # setting the hash of clicked rests 
      queues do |rest_id|
        @updated_restaurants[rest_id] = 0
      end

      # count how many times restaurants get clicks
      queues do |rest_id|
        @updated_restaurants[rest_id] = @updated_restaurants[rest_id] + 1
      end

      @updated_restaurants.each do |key, val|
        # If one restaurant has been clicked upon 5 times then needs an update
        if val.to_i > 5 then val = true
        else val = nil end
        @updated_restaurants[key] = val
      end

      # remove those don't need update
      @updated_restaurants.compact!
    end
  end
end
