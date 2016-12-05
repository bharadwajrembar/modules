require_relative '../../../puppet_x/puppetlabs/aws.rb'
Puppet::Type.type(:send_email).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine :aws => :aws
 
  def sender
  end

  def sender=(value)
    puts value
  end
end
