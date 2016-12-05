require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'base64'

Puppet::Type.type(:get_ips).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  remove_method :tags=

  def self.instances
    regions.collect do |region|
      begin
        instances = []
        subnets = Hash.new()

        subnets_response = ec2_client(region).describe_subnets()
        subnets_response.data.subnets.each do |subnet|
          subnet_name = name_from_tag(subnet)
          subnets[subnet.subnet_id] = subnet_name if subnet_name
        end

        ec2_client(region).describe_instances(filters: [
          {name: 'instance-state-name', values: ['pending', 'running', 'stopping', 'stopped']}
        ]).each do |response|
          response.data.reservations.each do |reservation|
            reservation.instances.each do |instance|
              hash = instance_to_hash(region, instance, subnets)
              instances << new(hash) if has_name?(hash)
            end
          end
        end
        instances
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:instance_id, :instance_type, :image_id, :region, :user_data,
            :key_name, :availability_zones, :security_groups, :monitoring,
            :subnet, :ebs_optimized, :block_devices, :private_ip_address,
            :iam_instance_profile_arn, :iam_instance_profile_name)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.instance_to_hash(region, instance, subnets)
    name = name_from_tag(instance)
    return {} unless name
    tags = {}
    subnet_name = nil
    monitoring = instance.monitoring.state == "enabled" ? true : false
    instance.tags.each do |tag|
      tags[tag.key] = tag.value unless tag.key == 'Name'
    end
    if instance.subnet_id
      subnet_name = subnets[instance.subnet_id] ? subnets[instance.subnet_id] : nil
    end

    devices = instance.block_device_mappings.collect do |mapping|
      {
        device_name: mapping.device_name,
        delete_on_termination: mapping.ebs.delete_on_termination,
      }
    end

    config = {
      name: name,
      id: instance.instance_id,
      ensure: instance.state.name.to_sym,
      tags: tags,
      region: region,
    }
    if instance.state.name == 'running'
      config[:private_ip_address] = instance.private_ip_address
    end
    config
  end

  def exists?
    Puppet.debug("Checking if instance #{name} exists in region #{target_region}")
    running?
  end

  def running?
    Puppet.debug("Checking if instance #{name} is running in region #{target_region}")
    [:present, :pending, :running].include? @property_hash[:ensure]
  end

  def using_vpc?
    resource[:subnet] || vpc_only_account?
  end

  def determine_subnet(vpc_ids)
    ec2 = ec2_client(resource[:region])
    # filter by VPC, since describe_subnets doesn't work on empty tag:Name
    subnet_response = ec2.describe_subnets(filters: [
      {name: "vpc-id", values: vpc_ids}])

    subnet_name = if (resource[:subnet].nil? || resource[:subnet].empty?) && vpc_only_account?
                    'default'
                  else
                    resource[:subnet]
                  end

    # then find the name in the VPC subnets that we have
    subnets = subnet_response.data.subnets.select do |s|
      if subnet_name.nil? || subnet_name.empty?
        ! s.tags.any? { |t| t.key == 'Name' }
      else
        s.tags.any? { |t| t.key == 'Name' && t.value == subnet_name }
      end
    end

    # Handle ambiguous name collisions by selecting first matching subnet / vpc.
    # This needs to be a stable sort to be idempotent and it needs to prefer the "a"
    # availability_zone as others might be less feature complete. Users always
    # have the option of overriding the subnet if that choice is not proper.
    subnet = subnets.sort { |a,b| [ a.availability_zone, a.subnet_id ] <=> [ b.availability_zone, b.subnet_id ] }.first
    if subnets.length > 1
      subnet_map = subnets.map { |s| "#{s.subnet_id} (vpc: #{s.vpc_id})" }.join(', ')
      Puppet.warning "Ambiguous subnet name '#{subnet_name}' resolves to subnets #{subnet_map} - using #{subnet.subnet_id}"
    end

    subnet
  end

  def config_with_private_ip(config)
    config['private_ip_address'] = resource['private_ip_address'] if resource['private_ip_address'] && using_vpc?
    config
  end

  def create
    @property_hash[:ensure] = :present
  end

  def destroy
    @property_hash[:ensure] = :absent
  end
end
