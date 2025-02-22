# Jun 2022: We had this set to 24 hours because a week was too long and "overnight" seemed reasonaable. But we slowed
# down the rate at which traits are ingested (b/c it was failing at faster rates) and now BIG jobs can take a few days!
Delayed::Worker.max_run_time = 4.days
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
# It's possible that something went wrong with Delayed::Job, but, really, we don't *usually* want to re-try jobs. :\
Delayed::Worker.max_attempts = 2
Delayed::Worker.queue_attributes = {
  harvest: { priority: 0 }
}
Delayed::Worker.raise_signal_exceptions = :term # unlock jobs on SIGTERM so that they can be picked up by the next available worker

# NOTE: If you add another one of these, you should really move them to a jobs folder.
DiffJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Delayed::Worker.logger.info("Publishing diff for resource [#{resource.name}](https://eol.org/resources/#{resource.id})")
    Publishing::Diff.by_resource(resource)
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

RepublishJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Delayed::Worker.logger.info("Publishing resource [#{resource.name}](https://eol.org/resources/#{resource.id})")
    Publishing::Fast.by_resource(resource)
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

ReindexJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Delayed::Worker.logger.info("Reindexing resource [#{resource.name}](https://eol.org/resources/#{resource.id})")
    resource.fix_missing_page_contents
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

FixNoNamesJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Delayed::Worker.logger.info("Fixing names for resource [#{resource.name}](https://eol.org/resources/#{resource.id})")
    resource.fix_no_names
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end
