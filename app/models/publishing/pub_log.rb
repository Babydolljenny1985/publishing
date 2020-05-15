# This is basically a façade around an ImportLog.
class Publishing::PubLog
  attr_accessor :logger, :resource

  def initialize(resource = nil, options = {})
    @resource = resource
    @logger = if @resource
      if options[:use_existing_log] || @resource.import_logs.count.zero?
        @resource.create_log # This is an ImportLog.
      else
        @resource.import_logs.last
      end
    else
      nil
    end
  end

  def log(what, type = nil)
    cat = type && type.key?(:cat) ? type[:cat] : :starts
    add_text_logs("(#{cat}) #{what}")
    @logger&.log(what, type)
  end

  def fail(e)
    add_text_logs("(errors) !! #{e.message}")
    count = 1
    root = Rails.root.to_s
    e.backtrace.each do |trace|
      trace = trace.sub(root, '[root]').sub(%r{\A.*/gems/}, '[gems]/')
      add_text_logs("(errors) (trace) #{trace}")
      if count >= 10
        more = e.backtrace.size - 10
        add_text_logs("(errors) (trace) SKIPPING #{more} MORE")
        break
      end
      count += 1
    end
    @logger&.fail(e)
  end

  def complete
    add_text_logs("(ends) completed resource #{@resource.name} (#{@resource.id})")
    @logger&.complete
  end

  def add_text_logs(str)
    t = Time.now.strftime('%H:%M:%S')
    Rails.logger.info("PUB[#{t}] #{str}")
    puts("[#{t}] #{str}")
  end
end
