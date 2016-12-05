Puppet::Type.newtype(:send_email) do
  @doc= 'Send an email to a list of recipients with a subject and a message'

  newparam(:name,:namevar => true) do
  end
 
  newproperty(:sender) do
  end
end
