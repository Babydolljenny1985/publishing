class PageDecorator < Draper::Decorator
  delegate_all

  def summary_hierarchy
    h.summary_hierarchy(object, true)
  end

  def full_hierarchy
    h.full_hierarchy(object, true)
  end

  def cached_summary
    Rails.cache.fetch("pages/#{id}/brief_summary") do
      BriefSummary.new(self, h).english # TODO: Someday we need to I18n this. ...somehow.
    end
  end

  def cached_summary_text
    Rails.cache.fetch("pages/#{id}/cached_summary_text") do
      sanitizer = Rails::Html::FullSanitizer.new
      sanitizer.sanitize(cached_summary.sentence)
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
