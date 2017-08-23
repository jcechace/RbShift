# coding: utf-8
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
      phase == 'Running'
    end

    def completed?
      reload
      phase == 'Completed'
    end
  end
end
