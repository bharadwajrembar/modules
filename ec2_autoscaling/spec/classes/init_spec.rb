require 'spec_helper'
describe 'ec2_autoscaling' do

  context 'with defaults for all parameters' do
    it { should contain_class('ec2_autoscaling') }
  end
end
