# frozen_string_literal: true

require_relative 'openshift_kind'

module RbShift
  # Representation of replication controller
  class ReplicationController < OpenshiftKind
    def phase
      obj[:metadata][:annotations]['openshift.io/deployment.phase'.to_sym]
    end

    def running?
      reload
      phase == 'Running' || phase == 'Pending'
    end

    def completed?
      reload
      phase == 'Completed'
    end

    def scaled?(replicas: 0)
      reload(true)
      return true if replicas == 0 and obj[:status][:replicas] == 0
      ready_replicas = obj[:status][:readyReplicas]
      !ready_replicas.nil? and ready_replicas == replicas
    end
  end
end
