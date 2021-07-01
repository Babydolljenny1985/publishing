class PageDecorator < Draper::Decorator
  delegate_all

  def summary_hierarchy
    h.summary_hierarchy(object, true)
  end

  def full_hierarchy
    h.full_hierarchy(object, true)
  end

  def summary
    # locale is included in the key because while all text should be English, any
    # links should be for the *current* locale to maintain locale stickiness.
    @summary ||= BriefSummary.english(self, h)
  end

  def cached_summary_text
    Rails.cache.fetch("pages/#{id}/cached_summary_text") do
      sanitizer = Rails::Html::FullSanitizer.new
      sanitizer.sanitize(summary.value)
    end
  end

  def associated_pages=(val)
    @associated_pages = val
  end

  def associated_page(id)
    raise TypeError.new("associated_pages not set") unless @associated_pages
    @associated_pages[id]
  end
end
