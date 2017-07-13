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

    def start_deployment
      @parent.execute "deploy #{name} --latest"
    end

    def deployments(update = false)
      dc_label = 'openshift.io/deployment-config.name'.to_sym
      if update || @_deployments.nil?
        @_deployments = @parent
                        .client
                        .get('replicationcontrollers', namespace: @parent.name)
                        .select { |item| item[:metadata][:annotations][dc_label] == @name }
                        .map { |item| ReplicationController.new(self, item) }
      end
      @_deployments
    end

    def running?
      !deployments(true).select(&:running?).empty?
    end
  end
end
