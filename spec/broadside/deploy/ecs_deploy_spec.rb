require 'spec_helper'

describe Broadside::EcsDeploy do
  include_context 'full configuration'

  let(:valid_options) { { target: :TEST_TARGET } }

  # TODO should be tested in a real config at the service: key
  let(:service_config) do
      {
        deployment_configuration: {
          minimum_healthy_percent: 0.5,
        }
      }
  end

  # TODO should be tested in a real config at the task_definition: key
  let(:task_definition_config) do
    {
      container_definitions: [
        {
          cpu: 1,
          memory: 2000,
        }
      ]
    }
  end

  let(:ecs_stub) { Aws::ECS::Client.new(region: Broadside.config.aws.region, credentials: Broadside.config.aws.credentials, stub_responses: true) }
  let(:deploy) { described_class.new(valid_options) }

  before(:each) { deploy.instance_variable_set(:@ecs_client, ecs_stub) }

  it 'should instantiate an object' do
    expect { deploy }.to_not raise_error
  end

  context 'bootstrap' do
    it 'fails without service_config' do
      expect { deploy.bootstrap }.to raise_error(/Service doesn't exist and cannot be created/)
    end

    it 'fails without task_definition_config' do
      deploy.deploy_config.service_config = service_config

      expect { deploy.bootstrap }.to raise_error(/No first task definition and cannot create one/)
    end

    it 'succeeds' do
      deploy.deploy_config.service_config = service_config
      deploy.deploy_config.task_definition_config = task_definition_config

      expect { deploy.bootstrap }.to_not raise_error
    end
  end

  context 'deploy' do
    it 'fails without an existing service' do
      expect { deploy.deploy }.to raise_error(/Service TEST_APP_TEST_TARGET does not exist/)
    end

    context 'with an existing service' do
      let :existing_service do
        {
          service_arn: "arn:aws:ecs:us-east-1:447374670232:service/events_test_ecs_script_2",
          service_name: "events_test_ecs_script_2",
          cluster_arn: "arn:aws:ecs:us-east-1:447374670232:cluster/c-large"
        }
      end

      let(:stub_response) { { services: [existing_service], failures: [] } }

      before(:each) do
        ecs_stub.stub_responses(:describe_services, stub_response)
      end

      it 'does not fail on service issues' do
        pending 'need to figure out how to stub a waiter'

        expect { deploy.deploy }.to_not raise_error
      end
    end
  end
end