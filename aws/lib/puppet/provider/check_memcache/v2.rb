require_relative '../../../puppet_x/puppetlabs/aws.rb'
Puppet::Type.type(:check_memcache).provide(:v2,:parent => PuppetX::Puppetlabs::Aws) do

  require 'dalli'
  require 'aws-sdk'

  def get_endpoint(cluster_id,region)

    # Create an Elasticache Client for the specified region
    begin
      elasticache = Aws::ElastiCache::Client.new(region:region)
    rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    # Describe existing cache clusters
    begin
      response = elasticache.describe_cache_clusters(cache_cluster_id: cluster_id)
    rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    # Check if the Elasticache cluster exists
    if response.cache_clusters.length == 0
      raise Puppet::Error, "Elasticache cluster #{cluster_id} does not exist"
    elsif response.cache_clusters.length > 1
      Puppet.info("Multiple cache clusters (#{response.cache_clusters.length} clusters) found by name #{cluster_id}")
      response.cache_clusters.each do |cluster|
        if cluster.engine == "memcached"
          Puppet.Info("Choosing #{cluster_id} with endpoint #{cluster.configuration_endpoint.address}:#{cluster.configuration_endpoint.port}")
          return cluster.configuration_endpoint.address+":"+cluster.configuration_endpoint.port
        end
      end
    else
      response.cache_clusters.each do |cluster|
        if cluster.engine == "memcached"
          return cluster.configuration_endpoint.address+":"+cluster.configuration_endpoint.port.to_s
        end
      end
    end
  end

  def check_connection(endpoint)
    options = {:expires_in => 10}
    cluster =  Dalli::Client.new(endpoint,options)

    begin
      check = cluster.alive!
    rescue Dalli::RingError,SocketError => ex
      return false
    else
      cluster.close
      return true
    end
  end

  def check_exists(cluster_id,region)
    # Create an Elasticache Client for the specified region
    begin
      elasticache = Aws::ElastiCache::Client.new(region:region)
    rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    # Describe existing cache clusters
    begin
      response = elasticache.describe_cache_clusters(cache_cluster_id: cluster_id)
    rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    # Check if the Elasticache cluster exists
    if response.cache_clusters.length == 0
      raise Puppet::Error, "Elasticache cluster #{cluster_id} does not exist"
    elsif response.cache_clusters.length > 1
      Puppet.info("Multiple cache clusters (#{response.cache_clusters.length} clusters) found by name #{cluster_id}")
      response.cache_clusters.each do |cluster|
        if cluster.engine == "memcached"
          Puppet.Info("Choosing #{cluster_id} with endpoint #{cluster.configuration_endpoint.address}:#{cluster.configuration_endpoint.port}")
          return cluster.cache_cluster_status
        end
      end
    else
      response.cache_clusters.each do |cluster|
        if cluster.engine == "memcached"
          return cluster.cache_cluster_status
        end
      end
    end
  end

  def check_availability(cluster_id,region)
    seconds = 30
    retries = 40
    count = 1
    available = ['available']
    wait = ['creating','modifying','rebooting cache cluster nodes','snapshotting']

    while count<=retries
      status = check_exists(cluster_id,region)
      if available.include? status
        endpoint = get_endpoint(cluster_id,region)
        con = check_connection(endpoint)
        if con == true
          Puppet.info("Connection to \"#{cluster_id}\" successful. Endpoint is \"#{endpoint}\"")
          return
        elsif con == false
          raise Puppet::Error, "Connection to \"#{cluster_id}\" with endpoint \"#{endpoint}\" failed."
        end
      elsif wait.include? status
        Puppet.info("Cluster \"#{cluster_id}\" is still in \"#{status}\". Will retry to check if available in #{seconds}. Try ##{count}")
        sleep seconds
      end
    end
  end

  def check_string(str)
    unless ((str.class == String) && (str.length > 0) && (str.length < 20))
      raise Puppet::Error, "Invalid Cache Cluster ID \"#{str}\". Must be greater than 0 and less than 20 characters."
    end
  end

  # Get all AWS regions
  def get_regions()
    regions = []
  
    begin
      ec2 = Aws::EC2::Client.new(region: 'us-east-1')
    rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: us-east-1"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    begin
      response = ec2.describe_regions()
    rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: us-east-1"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    response.regions.each do |reg|
      regions.push(reg.region_name)
    end
  
    return regions
  end

  # Verify the validity of specified AWS Region
  def verify_region(region)
    regions = []
    regions = get_regions()
  
    # Check if entered region is valid
    unless regions.include? region
      raise Puppet::Error, "[-] Invalid Region! Must be one among #{regions}"
    end
  end

  def region
  end

  def region=(value)
    verify_region(value)
  end

  def cluster_id
  end

  def cluster_id=(value)
    check_string(value)
  
    cluster_id = value
    region = @resource[:region]
    
    check_availability(cluster_id,region)
  end
end
