# frozen_string_literal: true

require 'net/http'

# Syncs vaccine Locations with LA County's data set.
class LocationSyncer < ApplicationService
  LA_URL = 'http://publichealth.lacounty.gov/acd/ncorona2019/js/pod-data.js'

  # Creates a LocationSyncer, setting @locations to the specified array of
  # location attributes. Defaults to LA County's locations.
  #
  # @param locations [Array] array of location-attribute hashes
  # @return [LocationSyncer]
  # @example
  #   LocationSyncer.new
  def initialize(locations = js_locations)
    super()
    @locations = locations
  end

  # Creates or updates Locations based on the array of location-attribute
  # hashes @locations.
  #
  # @return [Hash] results tallying zips and new, updated, and total Locations
  # @example
  #   LocationSyncer.call
  #     => {
  #             :new => 388,
  #         :updated => 0,
  #            :zips => [
  #                       "90044",
  #                       "91340",
  #                       ...
  #                     ],
  #           :total => 405
  #     }
  # rubocop:disable Metrics/MethodLength
  def call
    results = { new: 0, updated: 0, zips: Set.new }
    results[:total] = @locations.each do |attr|
      next if attr['addr1'].blank?

      if (location = Location.find_or_init(attr)).watched_attributes_changed?
        results[:zips] << location.zip
        log_location_change(location: location, results: results)
      end
      location.save
    end.size
    log_results(results)
    results
  end
  # rubocop:enable Metrics/MethodLength

  private

  def js_locations
    response = Net::HTTP.get(URI(LA_URL)).gsub('var unfiltered = ', '')
    JSON.parse(response).sort_by { |l| [l['id'].blank? ? 1 : 0, l['id'].to_i] } # sort blacnk IDs last
  end

  def log_location_change(location:, results:)
    if location.new_record? && results[:new] += 1
      Rails.logger.info "Adding zip #{location.zip} since Location #{location.id} is new"
    elsif location.changed? && results[:updated] += 1
      Rails.logger.info "Adding zip #{location.zip} since Location #{location.id} changed: #{location.changes}"
    end
  end

  def log_results(results)
    Rails.logger.info "Parsed #{results[:total]}, created #{results[:new]}, updated #{results[:updated]} Locations, "\
                      "which affected these zips: #{results[:zips]}."
  end
end
