require_relative '../../../puppet_x/puppetlabs/aws.rb'

# Get all AWS regions
def get_regions()
  regions = []

  begin
    ec2 = Aws::EC2::Client.new(region: 'us-east-1')
  rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
    if ex.message == 'Net::ReadTimeout'
      raise Puppet::Error,"Timeout while connecting to region: #{region}"
    else
      raise Puppet::Error,"Error: #{ex.message}"
    end
  end

  begin
    response = ec2.describe_regions()
  rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
    if ex.message == 'Net::ReadTimeout'
      raise Puppet::Error,"Timeout while connecting to region: #{region}"
    else
      raise Puppet::Error,"Error: #{ex.message}"
    end
  end

  response.regions.each do |reg|
    regions.push(reg.region_name)
  end

  return regions
end

Puppet::Type.type(:elasticache).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    instances = []
    regions.collect do |region|
      begin
        response = elasticache_client(region).describe_cache_clusters(show_cache_node_info: true)
      rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
      else
        response.cache_clusters.each do |cache|
          ids = []
        	if cache.engine == 'memcached'
            if cache.cache_cluster_status == 'creating' and cache.cache_cluster_status='modifying'
              instances << new({
                name: cache.cache_cluster_id,
                ensure: :present,
                engine: cache.engine,
                cache_subnet_group_name: cache.cache_subnet_group_name,
                num_cache_nodes: cache.num_cache_nodes,
                region: region,
                })
            elsif
              cache.cache_nodes.each do |node|
                ids.push(node.cache_node_id)
              end

              tags = []

              begin
                resp = iam_client().get_user()
              rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
                if ex.message == 'Net::ReadTimeout'
                  raise Puppet::Error,"Timeout while connecting to region: #{region}"
                else
                  raise Puppet::Error,"Error: #{ex.message}"
                end
              end

              arn = resp.user.arn

              account_no = arn.split(":")[4]
              resource_arn = "arn:aws:elasticache:#{region}:#{account_no}:cluster:#{cache.cache_cluster_id}"

              begin
                resp = elasticache_client(region).list_tags_for_resource({resource_name: resource_arn})
              rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
                if ex.message == 'Net::ReadTimeout'
                  raise Puppet::Error,"Timeout while connecting to region: #{region}"
                else
                  raise Puppet::Error,"Error: #{ex.message}"
                end
              end

              resp.tag_list.each do |tag|
                tags << {tag.key => tag.value}
              end

              instances << new({
		            name: cache.cache_cluster_id,
		            ensure: :present,
		            engine: cache.engine,
                    endpoint: cache.configuration_endpoint.address,
                    port: cache.configuration_endpoint.port,
                    available_cache_node_ids: ids,
		            cache_subnet_group_name: cache.cache_subnet_group_name,
		            cache_cluster_status: cache.cache_cluster_status,
		            num_cache_nodes: cache.num_cache_nodes,
		            region: region,
                    tags: tags,
		            })
            end
		    else
		     	instances << new({
		          name: cache.cache_cluster_id,
		          ensure: :present,
		          engine: cache.engine,
		          cache_subnet_group_name: cache.cache_subnet_group_name,
		          num_cache_nodes: cache.num_cache_nodes,
		          region: region,
                  tags: tags,
		          })
	        end
        end
      end
    end
    instances
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region and resource[:name] == prov.name
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def num_cache_nodes=(value)
    puts "no of nodes exists are #{num_cache_nodes}"
    if value < "#{num_cache_nodes}" and @resource[:cache_node_ids_to_remove] == nil
      raise Puppet::Error,"Both values num_cache_nodes and cache_node_ids_to_remove must pass when deleting nodes in cluster"
    else
      begin
        elasticache_client(@resource[:region]).modify_cache_cluster({cache_cluster_id: @resource[:name],num_cache_nodes: @resource[:num_cache_nodes],cache_node_ids_to_remove: @resource[:cache_node_ids_to_remove],apply_immediately: true})
      rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
      end
    end
  end

  def create
    Puppet.info("Creating New Elasticache Cluster")

    regions = get_regions()
    unless regions.include? @resource[:region]
      raise Puppet::Error, "Invalid Region! Must be among #{regions}"
    end

    tags_list = []
    @resource[:tags].each do |key,value|
      tags_list << {key: key, value: value}
    end

    sg_names = @resource[:security_group_names]
    region = @resource[:region]
    sg_ids = get_sg_ids(sg_names,region)

    if @resource[:engine] == "redis"
      if @resource[:num_cache_nodes] > '1'
        raise Puppet::Error,"num_cache_nodes should be only one 1 for redis cluster"
      else 
        begin
          response = elasticache_client(@resource[:region]).create_cache_cluster({cache_cluster_id: @resource[:name],engine: @resource[:engine],num_cache_nodes: '1' ,cache_node_type: @resource[:nodetype],cache_subnet_group_name: @resource[:cache_subnet_group_name],port: @resource[:port],engine_version: @resource[:engine_version],security_group_ids: sg_ids,tags: tags_list})
        rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
          if ex.message == 'Net::ReadTimeout'
            raise Puppet::Error,"Timeout while connecting to region: #{region}"
          else
            raise Puppet::Error,"Error: #{ex.message}"
          end
        end
        @property_hash[:ensure] = :present
      end
    else
      begin
        response = elasticache_client(@resource[:region]).create_cache_cluster({cache_cluster_id: @resource[:name],engine: @resource[:engine],num_cache_nodes: @resource[:num_cache_nodes],cache_node_type: @resource[:nodetype],cache_subnet_group_name: @resource[:cache_subnet_group_name],az_mode: @resource[:az_mode],port: @resource[:port],engine_version: @resource[:engine_version],tags: tags_list})
      rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
      end
      @property_hash[:ensure] = :present
    end
  end

  def get_sg_id(sg_names,region) 
    sg_ids = []
    
    begin
      ec2 = Aws::EC2::Client.new(region: region)
  	rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    begin
      response = ec2.describe_security_groups(group_names: sg_names)
    rescue Aws::EC2::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end

    if response.security_groups.length == 0
      raise Puppet::Error, "No security groups were found for the given name(s)"
    end

    response.security_groups.each do |sg|
      sg_ids.push(sg.group_id)
    end

    return sg_ids
  end

  def destroy
    Puppet.info("Destroying Cache Cluster #{name}")

    regions = get_regions()
    unless regions.include? @resource[:region]
      raise Puppet::Error, "Invalid Region! Must be among #{regions}"
    end

    begin
      elasticache_client(@resource[:region]).delete_cache_cluster({cache_cluster_id: @resource[:name]})
    rescue Aws::ElastiCache::Errors::ServiceError,StandardError,TimeoutError => ex
      if ex.message == 'Net::ReadTimeout'
        raise Puppet::Error,"Timeout while connecting to region: #{region}"
      else
        raise Puppet::Error,"Error: #{ex.message}"
      end
    end
    @property_hash[:ensure] = :absent
  end
end
