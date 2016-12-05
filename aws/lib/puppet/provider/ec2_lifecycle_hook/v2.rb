require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_lifecycle_hook).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws

  mk_resource_methods

  def self.instances
    instances = []
    regions.collect do |region|
      begin
        response = autoscaling_client(region).describe_auto_scaling_groups()
      rescue Aws::AutoScaling::Errors::ServiceError,StandardError,TimeoutError => ex
        if ex.message == 'Net::ReadTimeout'
          raise Puppet::Error,"Timeout while connecting to region: #{region}"
        else
          raise Puppet::Error,"Error: #{ex.message}"
        end
      else
        response.auto_scaling_groups.each do |group|
          resp = autoscaling_client(region).describe_lifecycle_hooks({auto_scaling_group_name: group.auto_scaling_group_name})
          resp.lifecycle_hooks.each do |hook|
            if hook.lifecycle_hook_name != nil
              instances << new({
                name: hook.lifecycle_hook_name,
                auto_scaling_group_name: hook.auto_scaling_group_name,
                ensure: :present,
                lifecycle_transition: hook.lifecycle_transition,
                default_result: hook.default_result,
                heartbeat_timeout: hook.heartbeat_timeout,
                region: region,
              })
            end
          end
        end
      end
    end
    instances
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region and resource[:auto_scaling_group_name] == prov.auto_scaling_group_name
      end
    end
  end

  def exists?
    Puppet.debug("Checking if lifecycle hook #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating Lifecycle Hook #{name} on Autoscaling Group: #{resource[:auto_scaling_group_name]}")
    autoscaling_client(@resource[:region]).put_lifecycle_hook({auto_scaling_group_name: @resource[:auto_scaling_group_name],lifecycle_hook_name: @resource[:name],lifecycle_transition: @resource[:lifecycle_transition],default_result: @resource[:default_result],heartbeat_timeout: @resource[:heartbeat_timeout]})
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting Lifecycle Hook #{name} from Autoscaling Group: #{resource[:auto_scaling_group_name]}")
    autoscaling_client(@resource[:region]).delete_lifecycle_hook({lifecycle_hook_name: @resource[:name],auto_scaling_group_name: @resource[:auto_scaling_group_name]})
    @property_hash[:ensure] = :absent
  end
end
