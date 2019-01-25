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
      return true if replicas.zero? && obj[:status][:replicas].zero?

      ready_replicas = obj[:status][:readyReplicas]
      !ready_replicas.nil? && ready_replicas == replicas
    end

    def pods(update = false)
      if update || @_pods.nil?
        @_pods = parent.parent.pods(update).select do |_, val|
          val.obj[:metadata][:annotations]['openshift.io/deployment.name'.to_sym] == @name
        end
      end
      @_pods
    end
  end
end
