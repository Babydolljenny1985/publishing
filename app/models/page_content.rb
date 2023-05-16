class PageContent < ApplicationRecord
  belongs_to :page
  belongs_to :source_page, class_name: "Page"
  belongs_to :content, polymorphic: true, inverse_of: :page_contents
  belongs_to :association_add_by_user, class_name: "User", optional: true

  has_many :curations

  default_scope { order(:position) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  scope :sources, -> { where("source_page_id = page_id") }

  scope :visible, -> { where(is_hidden: false) }
  scope :hidden, -> { where(is_hidden: true) }

  scope :trusted, -> { where(trust: PageContent.trusts[:trusted]) }
  scope :untrusted, -> { where(trust: PageContent.trusts[:untrusted]) }
  scope :not_untrusted, -> { where.not(trust: PageContent.trusts[:untrusted]) }

  scope :articles, -> { where(content_type: "Article") }

  scope :media, -> { where(content_type: "Medium") }

  counter_culture :page
  counter_culture :page,
    column_name: proc { |model| "#{model.content_type.pluralize.downcase}_count" },
    column_names: {
      ["page_contents.content_type = ?", "Medium"] => "media_count",
      ["page_contents.content_type = ?", "Article"] => "articles_count",
      ["page_contents.content_type = ?", "Link"] => "links_count"
    }

  acts_as_list scope: :page

  class << self
    def set_v2_exemplars(starting_page_id = nil, starting_order = nil)
      puts "[#{Time.now}] starting"
      last_flush = Time.now
      STDOUT.flush
      require 'csv'
      # Jamming this in the /public/data dir just so we can keep it between restarts!
      file = DataFile.assume_path('image_order.tsv')
      all_data = file.read_tsv
      per_cent = all_data.size / 100
      fixed_page = 0
      skipping_count = 0
      count_on_this_page = 0 # scope
      just_skipped_high_row = false # scope
      all_data[1..-1].each_with_index do |row, i|
        medium_id = row[0].to_i
        page_id = row[1].to_i
        order = row[2].to_i # 0-index
        begin
          if starting_page_id && page_id < starting_page_id
            if skipping_count.zero? || (skipping_count % 1000).zero?
              puts ".. Skipping #{page_id} (to get to #{starting_page_id}).."
              STDOUT.flush
            end
            next
          end
          if page_id == starting_page_id && starting_order && starting_order > order
            puts ".. Skipping #{page_id} position #{order} (to get to position #{starting_order}).."
            STDOUT.flush
            next
          end
          if order > 3000 # We don't *really* care about order past 3000 images
            puts ".. SKIPPING rows higher than 3000 for page #{page_id}" unless just_skipped_high_row
            just_skipped_high_row = true
            next
          end
          just_skipped_high_row = false
          if skipping_count >= 0
            puts "Starting with page #{page_id}"
            STDOUT.flush
            skipping_count = -1 # Stop notifications.
          end
          if fixed_page < page_id
            fixed_page = page_id
            fix_duplicate_positions(page_id)
            puts "[#{Time.now}] FIRST CONTENT FOR PAGE #{page_id}, % COMPLETE: #{i / per_cent}"
            STDOUT.flush
            last_flush = Time.now
            count_on_this_page = 0
          end
          last = (row[3] =~ /last/i) # 'first' or 'last'
          contents = PageContent.where(content_type: 'Medium', content_id: medium_id, page_id: page_id)
          if contents.any?
            content = contents.first # NOTE: #shift does not work on ActiveRecord_Relation, sadly.
            if contents.size > 1
              contents[1..-1].each { |extra| extra.destroy } # Remove duplicates
            end
            if last
              content.move_to_bottom # Let's not worry about the ORDER of the worst ones; I think it will naturally work.
            else
              if order.zero?
                PageIcon.create(page_id: page_id, medium_id: medium_id, user_id: 1)
                content.move_to_top
              else
                if count_on_this_page >= 100
                  puts "[#{Time.now}] .. moving #{medium_id} on page #{page_id} to position #{order + 1}"
                  STDOUT.flush
                  count_on_this_page = 0
                end
                retries ||= 0
                begin
                  content.insert_at(order + 1)
                rescue => e
                  if (retries += 1) < 3
                    puts "[#{Time.now}] !! ERROR: #{e} ... Sleeping (in case there's a publish happening)..."
                    sleep(120)
                    puts "[#{Time.now}] Retrying."
                    retry
                  end
                  puts "!! Too many retries. Moving on to the next page. YOU WILL HAVE TO RETRY PAGE #{page_id}!"
                  starting_page_id = page_id + 1
                end
              end
            end
            if (i % per_cent).zero? || last_flush < 5.minutes.ago
              puts "[#{Time.now}] % COMPLETE: #{i / per_cent}"
              STDOUT.flush
              last_flush = Time.now
            end
          else
            puts "[#{Time.now}] missing: content_type: 'Medium', content_id: #{medium_id}, page_id: #{page_id}"
            STDOUT.flush
          end # of check for content on this page
        rescue => e
          puts "[#{Time.now}] FAILED (#{e.message}) with page #{page_id} and position #{order}, row #{i}"
          STDOUT.flush
        ensure
          count_on_this_page += 1
        end
      end # of loop over all_data
      puts "[#{Time.now}] done."
      STDOUT.flush
    end

    def fix_duplicate_positions(page_id)
      PageContent.connection.execute("SET @rownum = 0;")
      PageContent.connection.execute(
        "UPDATE page_contents pc JOIN (\n"\
          "SELECT (@rownum :=@rownum + 1) row_num, id FROM page_contents WHERE page_id = #{page_id} ORDER BY position ASC\n"\
        ") nums ON pc.id = nums.id\n"\
        "SET pc.position = nums.row_num;"
      )

      exemplar = Page.find(page_id).page_icon&.page_content

      if exemplar
        exemplar.move_to_top
      end
    end

    def fix_exemplars
      # NOTE: this does NOT restrict by content_type because that slows the query WAAAAAAY down (it's not indexed)
      page_ids = uniq.pluck(:page_id)
      batches = (page_ids.size / 1000).ceil
      puts "++ Cleaning up #{page_ids.size} exemplars (#{batches} batches)..."
      batch = 1
      page_ids.in_groups_of(1000, false) do |group|
        puts "++ Batch #{batch}/#{batches}..."
        # NOTE: The #search_import is required because we're going to update Search... without that scope added, we end up
        # doing dozens of extra DB queries to build the Search JSON!
        Page.search_import.where(id: group).find_each do |page|
          # NOTE: yes, this will produce a query for EVERY page in the array. ...But it's very hard to limit the number of results from a join, and this isn't a method we'll run very often, so this is "Fine."
          medium_id = page.media.order(:position).limit(1).pluck(:id).first
          page.update_attribute(:medium_id, medium_id) unless page.medium_id == medium_id
        end
        batch += 1
      end
      puts "++ Done."
    end

    # TODO: Shoot. This really should move to Medium. :|
    def export_media_manifest
      require 'csv'
      @collection_num = 1
      @collection = [[
        'EOL content ID',
        'EOL page ID',
        'Medium Source URL',
        'EOL Full-Size Copy URL',
        'License Name',
        'Copyright Owner']]
      puts "start #{Time.now}"
      STDOUT.flush
      # NOTE: this no longer restricts itself to visible or trusated media, but I think that's fine for the use-case.
      Medium.where('page_id IS NOT NULL').includes(:license).find_each do |item|
        begin
          @collection << [item.id, item.page_id, item.source_url, item.original_size_url, item.license&.name,
            item&.owner]
        rescue => e
          puts "FAILED on page item #{item.id} (#{item.resource.name})"
          puts "ERROR: #{e.message}"
          STDOUT.flush
        end
        flush_collection if @collection.size >= 100_000
      end
      puts "end #{Time.now}"
      flush_collection unless @collection.empty?
    end

    # TODO: Shoot. This really should move to Medium. :|
    def flush_collection
      CSV.open(Rails.root.join('public', 'data', "media_manifest_#{@collection_num}.csv"), 'wb') do |csv|
        @collection.each { |row| csv << row }
      end
      @collection = []
      puts "flushed ##{@collection_num} @ #{Time.now}"
      STDOUT.flush
      @collection_num += 1
    end

    # Note: this is not meant to be fast, but really, isn't that bad. It takes a few hours to run (Apr 2023)
    def remove_all_orphans
      [Medium, Article].each do |klass|
        puts "=== #{klass.name}"
        Page.in_batches(of: 32) do |pages|
          page_ids = pages.pluck(:id)
          puts "PAGES: #{page_ids[0..3].join(',')}... (#{page_ids.count})\n\n"
          STDOUT.flush
          content_ids = PageContent.where(page_id: page_ids, content_type: klass.name).pluck(:content_id)
          puts "CONTENTS [#{page_ids.first}+]: #{content_ids[0..3].join(',')}... (#{content_ids.count})\n\n"
          # missing_ids = content_ids - klass.where(id: content_ids).pluck(:id)
          content_ids.each_slice(10_000) do |content_batch| 
            STDOUT.flush
            missing_ids = content_batch - klass.where(id: content_batch).pluck(:id)
            puts "MISSING (#{content_batch.first}...) [#{page_ids.first}+]: #{missing_ids.size}"
            # puts "REMOVED: #{PageContent.where(page_id: page_ids, content_id: missing_ids, content_type: klass.name).count}"
            # puts "FIND: PageContent.where(page_id: page_ids, content_id: #{missing_ids.first}, content_type: '#{klass.name}')"
            puts "REMOVED [#{page_ids.first}+]: #{PageContent.where(page_id: page_ids, content_id: missing_ids, content_type: klass.name).delete_all}"
          end
          puts "+++ Batch Completed (#{klass})..."
          STDOUT.flush
        end
      end
      puts "=== Complete."
      STDOUT.flush
    end
  end # of class methods
end
