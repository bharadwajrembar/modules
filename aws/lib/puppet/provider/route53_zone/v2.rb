require_relative '../../../puppet_x/puppetlabs/aws.rb'
require 'securerandom'

# Get all AWS regions
def get_regions()
  regions = []
  # Get all AWS Regions
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

def get_vpc_id(vpc_name,region)
  vpcid = ""
  vpcs = ec2_client(region).describe_vpcs(filters: [{name: "tag-key", values: ["Name"]},{name: "tag-value",values: [vpc_name]}])
  if vpcs.vpcs.length > 1
    Puppet.info("Multiple VPC's with the same name, obtaining VPC ID of the first")
    return vpcs.vpcs[0].vpc_id
  elsif vpcs.vpcs.length == 1
    return vpcs.vpcs[0].vpc_id
  elsif vpcs.vpcs.length == 0
    raise Puppet::Error, "No VPC by name \"#{vpc_name}\" found in #{region}"
  end
end

Puppet::Type.type(:route53_zone).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    begin
      response = route53_client.list_hosted_zones()
    rescue Aws::Route53::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
    else
      begin
        response.data.hosted_zones.collect do |zone|
          new({
            name: zone.name,
            ensure: :present,
            private_zone: zone.config.private_zone,
            resource_record_set_count: zone.resource_record_set_count,
            })
        end
      rescue Aws::Route53::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
      end
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    Puppet.info("Checking if zone #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    reference = SecureRandom.hex
    Puppet.info("Creating zone #{name} with #{reference}")
    if resource[:private_zone] == true
      regions = get_regions()
      if !(resource[:vpc_name].nil?) || (regions.include? resource[:region])
        vpc_id = get_vpc_id(resource[:vpc_name],resource[:region])
        Puppet.info("VPC ID chosen : #{vpc_id}")
        resp = route53_client.create_hosted_zone(
        name: name+'.',
        caller_reference: reference,
        hosted_zone_config: {private_zone: true},
        vpc: {
          vpc_region: resource[:region],
          vpc_id: vpc_id,
        }
      )
        @property_hash[:ensure] = :present
      else
        if !(regions.include? resource[:region])
          raise Puppet::Error, 'Failed to create private hosted zone as region is invalid'
        end
        if resource[:vpc_name].nil?
          raise Puppet::Error, 'Failed to create private hosted zone as VPC Name is either empty'
        end
      end
    elsif resource[:private_zone] == false
      route53_client.create_hosted_zone(
        name: name,
        caller_reference: reference,
        hosted_zone_config: {private_zone: false},
      )
      @property_hash[:ensure] = :present
    end
  end

  def destroy
    Puppet.info("Deleting zone #{name}")
    zones = route53_client.list_hosted_zones.data.hosted_zones.select { |zone| zone.name == name }
    zones.each do |zone|
      route53_client.delete_hosted_zone(id: zone.id)
    end
    @property_hash[:ensure] = :absent
  end
end
