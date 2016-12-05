Puppet::Type.newtype(:check_memcache) do
  @doc = "Check status of Memcache Cluster provisioned through Elasticache"
  newparam(:name) do
    desc "Title for provider"
  end
  newproperty(:cluster_id) do
    desc "The unique cluster name for the provisioned Memcache Cluster. Must be greater than 0 and less than 20 characters in length"
  end
  newproperty(:region) do
    desc "AWS Region"
  end
end
