class OccurrenceMap < ApplicationRecord
  belongs_to :page

  class << self
    def remove_pages_with_no_map(force = nil)
      bad_ids = []
      bad_pages = []
      where('page_id IS NOT NULL').find_each do |occ_map|
        path = Rails.public_path.join('data', 'map_data_dwca', (occ_map.page_id % 100).to_s, "#{occ_map.page_id}.json")
        bad_ids << occ_map.id unless File.exist?(path)
      end
      raise "ABORTING: #{bad_ids.size} is too many to remove." if !force && bad_ids.size >= (count / 10.0).ceil
      page_ids = Page.where(id: where(id: bad_ids).limit(109).pluck(:page_id)).limit(10).pluck(:id)
      Rails.logger.info("Sample of page IDs that will be affected: #{page_ids.join(', ')}.")
      total_removed = where(id: bad_ids).delete_all
      Rails.logger.info("Removed a total of #{total_removed} OccurrenceMap objects from the database.")
    end
  end
end
