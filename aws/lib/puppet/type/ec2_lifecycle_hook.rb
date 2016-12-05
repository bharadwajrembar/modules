Puppet::Type.newtype('ec2_lifecycle_hook') do
  @doc = 'Type to create a lifecycle hook for an autoscaling group'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Lifecycle Hook Name'
    validate do |value|
      fail 'Lifecycle hook must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'AWS Region to check/create/delete the lifecycle hooks for a particular auto-scaling group'
    regions = ['us-east-1','us-west-1','us-west-2','ap-south-1','ap-northeast-1','ap-northeast-2','ap-southeast-1','ap-southeast-2','eu-central-1','eu-west-1','sa-east-1']
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
      fail 'Invalid region!' unless regions.include? value
    end
  end

  newproperty(:default_result) do
    desc 'The default result to opt for when the lifecycle is completed'
    results = ['CONTINUE','ABANDON']
    validate do |value|
      fail 'default result must either be CONTINUE or ABANDON!' unless results.include? value
    end
  end

  newproperty(:lifecycle_transition) do
    desc 'The lifecycle transition for which the hook is applied for, ie, either on launching or termination of instances in an autoscaling group'
    results = ['autoscaling:EC2_INSTANCE_LAUNCHING','autoscaling:EC2_INSTANCE_TERMINATING']
    validate do |value|
      fail 'lifecycle transition must either be autoscaling:EC2_INSTANCE_LAUNCHING or autoscaling:EC2_INSTANCE_TERMINATING!' unless results.include? value
    end
  end

  newproperty(:heartbeat_timeout) do
    desc 'The maximum time, in seconds, that can elapse before the lifecycle hook times out'
  end

  newproperty(:auto_scaling_group_name) do
    desc 'Autoscaling Group Name of the Lifecycle Hook'
    validate do |value|
      fail 'Autoscaling Group must have a name' if value == ''
      fail 'Autoscaling Group name should be a String' unless value.is_a?(String)
    end
  end
end
