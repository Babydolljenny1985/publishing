class PageStatUpdater
  BATCH_SIZE = 1000
  
  class << self
    def run
      batch = 0
      page_ids = []

      while batch == 0 || page_ids.any?
        puts "Fetching batch #{batch} (x #{BATCH_SIZE}) of page_ids"
        page_ids = fetch_batch(batch)

        page_ids.each do |page_id|
          update_counts(page_id)
        end

        batch += 1
      end 
    end

    def fetch_batch(batch)
      q = %Q(
        MATCH (p:Page)
        WHERE (:Page)-[:parent*2]->(p)
        RETURN p.page_id
        ORDER BY p.page_id
        SKIP #{batch * BATCH_SIZE}
        LIMIT #{BATCH_SIZE}
      )
      res = TraitBank.query(q)
      res["data"].flatten
    end

    def update_counts(page_id)
      puts "updating counts for page #{page_id}"

      q = %Q(
        MATCH (anc:Page{ page_id: #{page_id} }), (desc:Page)-[:parent*0..]->(anc)
        OPTIONAL MATCH (desc)-[:trait|:inferred_trait]->(trait:Trait)
        OPTIONAL MATCH (obj_trait:Trait)-[:object_page]->(desc)
        WITH anc, count(DISTINCT desc) AS desc_count, count(obj_trait) AS obj_trait_count
        SET anc.descendant_count = desc_count
        SET anc.obj_trait_count = obj_trait_count
      )

      TraitBank.query(q)
    end
  end
end

