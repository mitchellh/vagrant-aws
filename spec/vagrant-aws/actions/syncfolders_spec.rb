require 'spec_helper'
require 'vagrant-aws/action/sync_folders'

describe VagrantPlugins::AWS::Action::SyncFolders do
  let(:app) { nil }
  let(:env) { {} }
  subject(:action) { described_class.new(app, env) }

  describe '#ssh_options_to_args' do
    subject(:args) { action.ssh_options_to_args(options) }

    context 'with no ssh options' do
      let(:options) { [] }

      it { should eql [] }
    end

    context 'with one option' do
      let(:options) { ['StrictHostKeyChecking=no'] }
      it { should eql ["-o 'StrictHostKeyChecking=no'"] }
    end

    context 'with multiple options' do
      let(:options) { ['SHKC=no', 'Port=222'] }
      it { should eql ["-o 'SHKC=no'", "-o 'Port=222'"] }
    end
  end

  describe '#create_guest_path_command' do
    subject(:args) { action.create_guest_path_command(path, communicator) }

    context 'communicator is not winrm' do
      let(:path) { '/tmp2' }
      let(:communicator) { :ssh }
      it { should eql "mkdir -p '/tmp2'" }
    end

    context 'communicator is winrm' do
      let(:path) { 'C:\tmp2' }
      let(:communicator) { :winrm }
      it { should eql "mkdir 'C:\\tmp2'" }
    end
  end
end
