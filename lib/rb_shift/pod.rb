# frozen_string_literal: true

require_relative 'openshift_kind'

module RbShift
  # Pod class
  class Pod < OpenshiftKind
    # @api public
    # Function to download files from the pod
    #
    # @param [string] client_location Where in the computer will be file synced
    # @param [string] pod_location Where in the pod is the file located
    # @param [bool] to_pod Whether to sync to pod or from pod, default is false
    def rsync(client_location:, pod_location:, to_pod: false, **kwargs)
      full_pod = "#{name}:#{pod_location}"
      dirs     = [full_pod, client_location]
      dirs.reverse! if to_pod
      command_params = dirs.join(' ')
      execute("rsync #{command_params}", **kwargs)
    end

    def logs(update = false)
      if update || @_logs.nil?
        @_logs = @parent.client.get(
            Pod.resource_name, namespace: @namespace, name: @name, attribute: 'log', raw: true
        )
      end

      @_logs
    end
  end
end
