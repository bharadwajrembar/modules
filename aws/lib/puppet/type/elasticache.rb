Puppet::Type.newtype('elasticache') do
  @doc = 'Type to create Elasticache'

  ensurable

  newproperty(:engine) do
    desc 'The name of the Engine must be either memcached or redis.'
    allowed=['memcached','redis']
    validate do |value|
      fail 'Engine must be either memcached or redis' unless allowed.include? value
    end
  end

  newparam(:name, namevar: true) do
    desc 'The name of the Cache Cluster.'
    validate do |value|
      fail 'Cache Cluster must have a name' if value == ''
      fail 'Cache Cluster name length must be less than or equal to 20 characters' if value.length > 20
      fail 'Cache Cluster name should be a String' unless value.is_a?(String)
      fail 'Cache Cluster name must starts with letter' unless value[0] =~ /[aA-zZ]/
    end
  end

  newproperty(:cache_subnet_group_name) do
    desc 'cache_subnet_group_name to create cache cluster.'

  end

  newproperty(:cache_cluster_status) do
    desc 'Cache cluster status'
  end

  newproperty(:available_cache_node_ids) do
    desc 'Available cache node ids'
  end

  newproperty(:port) do
    desc 'Port Number to use for Cache Cluster'
  end

  newproperty(:endpoint) do
  end

  newproperty(:security_group_names) do
    desc 'Security Groups associate with Cache Cluster with in VPC'

  end

  newproperty(:num_cache_nodes) do
    desc 'The number of nodes in Cache Cluster.'
  end

  newproperty(:tags) do
    desc 'Tags for the Cache Cluster.'
  end

  newproperty(:cache_node_ids_to_remove,:array_matching => :all) do
    desc 'The node id of cache node to remove from Cache Cluster'
  end

  newproperty(:engine_version) do
    desc 'Cache Cluster engine version'

  end

  newproperty(:az_mode) do
    desc 'Cache Cluster az_mode '
    validate do |value|
      fail 'az_mode must have a value' if value == ''
      fail 'az_mode should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:nodetype) do
    desc 'Type of nodes in Cache Cluster.'
  end

  newproperty(:region) do
    desc 'The region to create the Elasticache'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end
end
