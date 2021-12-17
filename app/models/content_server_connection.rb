class ContentServerConnection
  TRAIT_DIFF_SLEEP = 10
  MAX_TRAIT_DIFF_TRIES = 30 # * 10s = 30 = 300s = 5 mins

  def initialize(resource, log = nil)
    @resource = resource
    repo_url = Rails.application.secrets.repository[:url]
    @repo_site = URI(repo_url)
    @log = log # Okay if it's nil.
    @unacceptable_codes = 300
    @trait_diff_tries = 0
  end

  def is_on_this_host?
    @repo_is_on_this_host ||= (@repo_site.host == '128.0.0.1' ||  @repo_site.host == 'localhost')
  end

  def file_url(name)
    "/data/#{@resource.path}/publish_#{name}"
  end

  def exists?(name)
    url = URI.parse(file_url(name)) # e.g.: "/data/NMNHtypes/publish_publish_metadata.tsv"
    req = Net::HTTP.new(@repo_site.host, @repo_site.port)
    req.use_ssl = @repo_site.scheme == 'https'
    res = req.request_head(url.path)
    res.code.to_i < @unacceptable_codes
  end

  def copy_file(local_name, remote_name)
    open(local_name, 'wb') { |f| f.write(file(remote_name)) }
  end

  def copy_file_for_remote_url(local_path, remote_url)
    open(local_path, 'wb') { |f| f.write(file_for_url(remote_url)) }
  end

  def file(name)
    file_for_url(file_url(name))
  end

if nil
end

  def file_for_url(url)
    # Need to get the _harvester_session cookie or this will not work:
    uri = URI.parse(Rails.application.secrets.repository[:url] + '/')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    cookies = response.response['set-cookie']
    request = Net::HTTP::Get.new(url)
    request['Cookie'] = cookies
    response = http.request(request)
    if response.code.to_i >= @unacceptable_codes
      log_warn("MISSING #{@repo_site}#{url} [#{response.code}] (#{resp.size} bytes); skipping")
      return false
    elsif response.body.size < response.content_length - 1
      log_warn("TRUNCATED RESPONSE! Got #{response.body.size} bytes out of #{response.content_length}")
      return false
    end
    response.body.gsub(/\\\n/, "\n").gsub(/\\N/, '')
  end

  def trait_diff_metadata
    @trait_diff_tries = 0
    trait_diff_metadata_helper
  end

  def log_info(what)
    if @log.respond_to?(:log)
      @log.log(what.to_s, cat: :infos)
    else
      puts what
    end
  end

  def log_warn(what)
    if @log.respond_to?(:log)
      @log.log(what.to_s, cat: :warns)
    else
      puts "!! WARNING: #{what}"
    end
  end

  class TraitDiffMetadata
    attr_reader :new_traits_file, :removed_traits_file, :new_metadata_file

    def initialize(json, resource, connection)
      @remove_all_traits = json['remove_all_traits']

      new_traits_path_remote = json['new_traits_path']
      removed_traits_path_remote = json['removed_traits_path']
      new_metadata_path_remote = json['new_metadata_path']

      new_traits_path = local_path(new_traits_path_remote, resource)
      removed_traits_path = local_path(removed_traits_path_remote, resource)
      new_metadata_path = local_path(new_metadata_path_remote, resource)

      copy_file(new_traits_path, new_traits_path_remote, connection)
      copy_file(removed_traits_path, removed_traits_path_remote, connection)
      copy_file(new_metadata_path, new_metadata_path_remote, connection)

      @new_traits_file = new_traits_path.nil? ? nil : File.basename(new_traits_path)
      @removed_traits_file = removed_traits_path.nil? ? nil : File.basename(removed_traits_path)
      @new_metadata_file = new_metadata_path.nil? ? nil : File.basename(new_metadata_path)
    end

    def remove_all_traits?
      @remove_all_traits
    end

    private
    def local_path(remote_path, resource)
      remote_path.nil? ?
        nil :
        resource.ensure_file_dir.join(File.basename(remote_path))
    end

    def copy_file(local, remote, conn)
      conn.copy_file_for_remote_url(local, remote) unless local.nil?
    end
  end

  private
  def trait_diff_metadata_helper
    if @trait_diff_tries == MAX_TRAIT_DIFF_TRIES
      log_warn("Max trait diff tries reached; giving up")
      return nil
    end

    url = "/resources/#{@resource.repository_id}/publish_diffs.json"
    url += "?since=#{@resource.last_published_at.to_i}" unless @resource.last_published_at.nil?

    log_info("polling for trait diff metadata: #{url}")

    resp = nil

    Net::HTTP.start(@repo_site.host, @repo_site.port, use_ssl: @repo_site.scheme == 'https') do |http|
      resp = http.get(url)
    end

    unless resp.is_a?(Net::HTTPSuccess)
      raise "Got unexpected response code from #{url}: #{resp.code}"
    end

    result = JSON.parse(resp.body)
    @trait_diff_tries += 1
    return handle_trait_diff_metadata_resp(result)
  end

  def handle_trait_diff_metadata_resp(json)
    status = json['status']

    case status
    when 'completed'
      return TraitDiffMetadata.new(json, @resource, self)
    when 'pending', 'enqueued', 'processing'
      sleep 10
      return trait_diff_metadata_helper
    else
      raise "Got unexpected status from trait diff metadata request: #{status}"
    end
  end

end
