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

        rests.each do |key, val|
          # If one restaurant has been clicked upon 5 times then needs an update
          rest_id = key.to_s
          clicks = val.to_i
          if clicks >= 5
            do_db_update(rest_id)
            puts "\tRestaurant #{rest_id} has been clicked #{clicks} times, update has done."
          else
            puts "\tRestaurant #{rest_id} has been clicked #{clicks} times, don't need update (under 5)."
          end
        end
      else
        puts "\tNo update restaurants need for today."
      end
    end

    def do_db_update(rest_id)
      # get rest entity
      rest_entity = Repository::RestaurantDetails.find_by_rest_id(rest_id)
      puts rest_entity.inspect
      # get rebuilt repo entity
      # here will auto update click數量
      # update(entity, first_time_or_not)
      rest_detail_entity = Restaurant::RestaurantDetailMapper.new(rest_entity, @config.GMAP_TOKEN).gmap_place_details
      # update cover_pictures as well
      trim_name = rest_detail_entity.name.gsub(' ', '')
      cover_pics = Restaurant::CoverPictureMapper.new(@config.GMAP_TOKEN, @config.CX, trim_name).cover_picture_lists
      new_cover_pic_entities = Restaurant::CoverPictureMapper::BuildCoverPictureEntity.new(cover_pics).build_entity
      cov_pic_repo_entities = Repository::CoverPictures.db_update(new_cover_pic_entities, rest_detail_entity.id)
      # update restaurant
      repo_entity = Repository::RestaurantDetails.update(rest_detail_entity, false)
      puts repo_entity.inspect
    end

    def update_restaurants
      return @updated_restaurants if @updated_restaurants

      # default hash value is 0
      @updated_restaurants = Hash.new(0)
      @queue.poll do |queue|
        puts queue.inspect
        puts queue.class
        # count how many times restaurants get clicks
        rest_id = queue
        @updated_restaurants[rest_id] = @updated_restaurants[rest_id] + 1
      end
      @updated_restaurants
    end
  end
end
