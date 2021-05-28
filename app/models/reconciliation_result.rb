class ReconciliationResult
  ManifestType = Struct.new(:id, :name)
  TYPE_TAXON = ManifestType.new("taxon", "Taxon")
  MANIFEST_TYPES = [ReconciliationResult::TYPE_TAXON]
  MAX_SCORE = 100
  PROPERTY_HANDLERS = {
    'ancestor' => :handle_ancestor_property
  }

  def initialize(query_hash)
    @raw_queries = query_hash
    build_results
  end

  def to_h
    @queries.map { |q| [q.key, q.result_hash] }.to_h
  end

  private
  class Query
    attr_reader :key, :query_string, :searchkick_query


    PROPERTY_HANDLERS = {
      'ancestor' => :handle_ancestor_property
    }

    MAIN_QUERY_WEIGHT = 2

    PROPERTY_WEIGHTS = {
      'ancestor' => 1
    }

    def initialize(key, raw_query)
      @key = key
      @main_query = PageQuery.new(raw_query['query'], raw_query['limit'])
      build_property_scorers(raw_query) # sets @property_scorers and @property_queries
    end

    def query_string
      @main_query.query_string
    end

    def searchkick_query
      @main_query.searchkick_query
    end

    def all_searchkick_queries
      result = [searchkick_query] + @property_queries # TODO: Placeholder
    end

    def result_hash
      return @result_hash if @result_hash

      hash_results = ScoredPage.from_searchkick_results(query_string, searchkick_query).map do |sp|
        total_weights = MAIN_QUERY_WEIGHT
        total_score = sp.score * MAIN_QUERY_WEIGHT
        confident_match = sp.confident_match

        @property_scorers.each do |key, scorers|
          weight = PROPERTY_WEIGHTS[key]
          total_weights += weight
          # average of all scores for given property
          score = scorers.map { |s| s.score(sp.page) }.sum(0.0) / scorers.length
          total_score += score * weight
          confident_match = confident_match && score > 0
        end

        final_score = total_score * 1.0 / total_weights

        { 
          id: "pages/#{sp.page.id}", 
          name: sp.page.scientific_name_string, 
          score: final_score,
          type: [{ id: TYPE_TAXON.id, name: TYPE_TAXON.name }],
          match: sp.confident_match
        }
      end.sort { |a, b| b[:score] <=> a[:score] }

      @result_hash = { result: hash_results }
    end

    private
    def handle_ancestor_property(value)
      if value.is_a?(Hash)
        AncestorScorer.for_entity_hash(value)
      else
        AncestorScorer.for_query_string(value)
      end
    end

    def build_property_scorers(raw_query)
      # only 'ancestor' supported currently
      @property_queries = []
      @property_scorers = (raw_query['properties'] || []).map do |property|
        id = property['pid'] 
        handler = PROPERTY_HANDLERS[id]

        next nil unless handler

        value = property['v']
        values = value.is_a?(Array) ? value : [value]
        scorers = values.map { |v| self.send(handler, v) }

        scorers.each do |s|
          scorer_query = s.searchkick_query
          @property_queries << scorer_query if scorer_query
        end

        [id, scorers]
      end.compact.to_h
    end
  end

  def build_results
    @queries = @raw_queries.map { |k, v| Query.new(k, v) }
    execute_queries
  end

  def execute_queries
    all_queries = []

    # flatten *doesn't* work here -- it will execute each query since they respond to flatten!
    @queries.each do |q| 
      q.all_searchkick_queries.each do |sq|
        all_queries << sq
      end
    end

    Searchkick.multi_search(all_queries)
  end
end

