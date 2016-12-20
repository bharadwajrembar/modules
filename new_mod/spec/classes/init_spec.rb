require 'spec_helper'
describe 'new_mod' do

  context 'with defaults for all parameters' do
    it { should contain_class('new_mod') }
  end
end
