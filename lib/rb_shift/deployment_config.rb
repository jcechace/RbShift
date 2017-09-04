# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'
require_relative 'replication_controller'

module RbShift
  # Representation of OpenShift deployment config
  class DeploymentConfig < OpenshiftKind
    def scale(replicas)
      @parent.execute "scale dc #{name}", replicas: replicas
    end

    def start_deployment(block = false, timeout = 10)
      @parent.execute "rollout latest #{name}"
      sleep timeout
      deployments(true)
      sleep timeout while running? && block
    end

    # rubocop:disable Layout/ExtraSpacing
    def deployments(update = false)
      dc_label = 'openshift.io/deployment-config.name'.to_sym
      if update || @_deployments.nil?
        items = @parent.client
                       .get('replicationcontrollers', namespace: @parent.name)
                       .select { |item| item[:metadata][:annotations][dc_label] == @name }

        @_deployments = items.each_with_object({}) do |item, hash|
          resource            = ReplicationController.new(self, item)
          hash[resource.name] = resource
        end
      end
      @_deployments
    end

    def running?(reload = false)
      deployments(true) if reload
      !deployments.values.select(&:running?).empty?
    end
  end
end
