# WARNING: work in progress! Use at your own risk.
# This is a utility for syncing a local resource with, say, beta (or other configured resource_authority)
require 'json'

class Resource::RemoteImporter
  RA_URL = Rails.application.config.x.resource_authority
  JSON_URL_FMT = "#{RA_URL}/resources/by_abbr/%s.json"
  REASSIGN_ID_OFFSET = 100

  def initialize(abbr)
    @abbr = abbr
  end 

  def import
    uri = URI(JSON_URL_FMT % @abbr)
    res = Net::HTTP.get(uri)
    remote_data = JSON.parse(res)
    resource = Resource.find_by_abbr(@abbr)

    if resource
      proceed = compare_and_ask_to_proceed(remote_data, resource)
      return unless proceed 
    else
      resource = Resource.new
    end

    existing_for_id = !resource || resource.id != remote_data['id'] ?
      Resource.find_by(id: remote_data['id']) : nil

    if existing_for_id
      new_id = next_available_id(existing_for_id.id)
      puts "A resource with id #{remote_data['id']} already exists! Ok to reassign it to #{new_id}? (y/n)"

      ok = gets.strip
      return unless ok == 'y'

      existing_for_id.update!(id: new_id)
    end

    resource.assign_attributes(remote_data)
    resource.save!

    puts "Done! See /resources/#{resource.id}"
  end

  private
  def compare_and_ask_to_proceed(remote_data, existing)
    puts "A Resource with abbreviation #{@abbr} already exists!"

    diff_keys = []
    existing_data = existing.attributes
    
    remote_data.keys.each do |k|
      remote_val = remote_data[k]
      existing_val = existing_data[k]

      if remote_val != existing_val
        diff_keys << k 
      end
    end

    if diff_keys.empty?
      puts "It does not differ from the remote version. Aborting since there's nothing to do."
      return false
    end

    puts "Diff with remote data:"
    puts "key\tlocal\tremote"

    diff_keys.each do |k|
      puts "#{k}\t#{existing_data[k]}\t#{remote_data[k]}"
    end

    if diff_keys.include?('id')
      puts "WARNING: local id differs from remote. Proceeding could result in corrupt data!"
    end

    puts "Update existing resource? (y/n)"
    response = gets.strip

    return true if response == "y"

    false
  end

  def next_available_id(resource)
    existing = resource 
    id = resource.id

    while existing
      id += REASSIGN_ID_OFFSET
      existing = Resource.find_by(id: id)
    end

    id
  end
end

