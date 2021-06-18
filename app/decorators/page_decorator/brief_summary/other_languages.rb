class PageDecorator
  class BriefSummary
    class OtherLanguages
      include BriefSummary::Shared

      attr_reader :view

      def initialize(page, view)
        @page = page
        @view = view

        # TODO: extract/remove these!
        @sentences = []
        @terms = []
        @full_name_used = false
      end

      def add_sentences
        if is_above_family?
          above_family
        elsif a1.present?
          if is_family?
            add_family_sentence
          elsif below_family?
            below_family_taxonomy_sentence
          end
        end
      end

      def below_family_taxonomy_sentence
        add_sentence do
          if a2.present?
            I18n.t(
              "brief_summary.below_family_taxonomy.with_family.#{@page.rank.treat_as}", 
              name1: full_name_clause,
              name2: a1,
              name3: a2
            )
          else
            I18n.t(
              "brief_summary.below_family_taxonomy.no_family.#{@page.rank.treat_as}", 
              name1: full_name_clause,
              name2: a1
            )
          end
        end
      end

      def above_family
        add_above_family_group_sentence
      end
    end
  end
end
