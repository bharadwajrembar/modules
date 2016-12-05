Puppet::Type.newtype(:route53_zone) do
  @doc = 'Type representing an Route53 DNS zone.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of DNS zone group.'
    validate do |value|
      fail Puppet::Error, 'Empty values are not allowed' if value == ''
    end
  end

  newproperty(:private_zone) do
    desc 'Indicates if private or public hosted zone'
    allowed = [true,false]
    validate do |value|
      fail 'Value must be either true or false' unless allowed.include? value
    end
  end

  newproperty(:region) do
    desc 'AWS Region to create a private hosted zone'
  end

  newproperty(:resource_record_set_count) do
    desc 'AWS Region to create a private hosted zone'
  end

  newproperty(:vpc_name) do
    desc 'VPC Name to associate the private hosted zone with'
  end
end
