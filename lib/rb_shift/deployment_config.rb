# frozen_string_literal: true

require 'timeout'

require_relative 'openshift_kind'
require_relative 'replication_controller'

module RbShift
  # Representation of OpenShift deployment config
  class DeploymentConfig < OpenshiftKind
    def scale(replicas, block: false, timeout: 60, polling: 5)
      log.info "Scaling deployment from deployment config #{name} to #{replicas} replicas"
      @parent.execute "scale dc #{name}", replicas: replicas
      wait_for_scale(replicas: replicas, timeout: timeout, polling: polling) if block
    end

    def wait_for_scale(replicas: 0,timeout: 60, polling: 5)
      Timeout.timeout(timeout) do
        log.info("Waiting for scale of #{name} for #{timeout} seconds...")
        loop do
          log.debug("--> Checking deployment after #{polling} seconds...")
          sleep polling
          break if scaled?(reload: true, replicas: replicas)
        end
      end
    end

    def scaled?(reload: false, replicas: 1)
      deployments(true) if reload
      deployments.values.last.scaled?(replicas: replicas)
    end

    # @param [Bool] block If true blocks until redeployment is finished
    # @param [Fixnum] timeout Maximum time to wait
    # @param [Fixnum] polling State checking period
    def start_deployment(block: false, timeout: 60, polling: 5)
      log.info "Starting deployment from deployment config #{name}"
      @parent.execute "rollout latest #{name}"
      sleep polling * 2
      deployments(true)
      wait_for_deployments(timeout: timeout, polling: polling) if block
    end

    def wait_for_deployments(timeout: 60, polling: 5)
      Timeout.timeout(timeout) do
        log.info "Waiting for deployments of #{name} for #{timeout} seconds..."
        loop do
          log.debug "--> Checking deployments after #{polling} seconds..."
          sleep polling
          break unless running?(true)
        end
      end
      log.info 'Deployments finished'
    end

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

    # Lists environment variables
    #
    # @param [String, nil] container_name Name of the container or nil for arbitrary container
    # @return [Hash] A hash of environment variables
    def env_variables(container_name = nil)
      unless @_env
        cont       = container(container_name)
        @_env      = cont[:env].each_with_object({}) do |var, env|
          env[var[:name]] = var.fetch(:value) { resolve_value(var[:valueFrom]) }
        end
      end
      @_env
    end

    # Sets environment variables
    # Using nil as a value will unset that variable
    #
    # @param [String, nil] container_name Name of the container where the environment is set
    # @param [Bool] block If true blocks until redeployment is finished
    # @param [Fixnum] timeout Maximum time to wait
    # @param [Fixnum] polling State checking period
    # @param [Hash] env Environment variables
    def set_env_variables(container_name = nil, block: false, timeout: 60, polling: 5, **env)
      env_string       = env.map { |k, v|  v ? "#{k}=#{v}" : "#{k}-" }.join(' ')
      container_name ||= container[:name]
      log.info "Setting env variables (#{env_string}) for #{name}/#{container_name}"
      @parent.execute("set env dc/#{container_name} #{env_string}")
      sleep polling
      wait_for_deployments(timeout: timeout, polling: polling) if block
      reload(true)
      @_env = nil
    end

    # Creates a new volume and adds it to the container
    #
    # @param [String] container_name Container's name
    # @param [String] volume_name Volume's name
    # @param [Hash] volume_config Volume config, if not set, volume is not created
    # @param [String] mount_path Mount path, if not set and mount_config is not set either,
    # volume is not mounted
    # @param [Hash] mount_config Mount config, see (mount_path)
    # @param [Bool] block If true blocks until redeployment is finished
    # @param [Fixnum] timeout Maximum time to wait
    # @param [Fixnum] polling State checking period
    def add_volume(container_name: nil, volume_name: nil, volume_config:, mount_path: nil,
                   mount_config: {}, block: false, timeout: 60, polling: 5)

      create_volume(volume_name, config: volume_config)
      mount_volume(container_name,
                   volume_name: volume_name,
                   mount_path:  mount_path,
                   **mount_config)

      update
      sleep polling
      wait_for_deployments(timeout: timeout, polling: polling) if block
      reload(true)
    end

    private

    # Resolve environment reference to a Secret or a ConfigMap
    # @param [Hash] obj valueFrom reference
    # @return [String] resolved value from the ConfigMap or a Secret
    def resolve_value(obj)
      project = @parent
      kind = case
             when (ref = obj[:configMapKeyRef]) then ConfigMap
             when (ref = obj[:secretKeyRef]) then Secret
             else
               log.debug "Unable to resolve value of #{obj}"
               return
             end

      # TODO: would be nicer if this would be provided by the Project (and not need to load ALL objects of the same type)
      resource = kind.new(project, project.client.get(kind.resource_name, name: ref.fetch(:name), namespace: project.name))
      resource[ref[:key]]
    end
        
    # Gets template spec
    # @return [Hash] Template spec
    def template_spec
      @obj[:spec][:template][:spec]
    end

    # Gets container
    # @param [String] name Container's name, if not provided, first container is selected
    # @return [Hash] Container
    def container(name = nil)
      if name
        template_spec[:containers].find { |c| c[:name] == name }
      else
        template_spec[:containers][0]
      end
    end

    # Gets volumes
    # @return [Array] Volumes
    def volumes
      template_spec[:volumes] ||= []
    end

    # Gets volume
    # @param [String] name , name, if not provided, first volume is selected
    # @return [Hash] Container
    def volume(name = nil)
      if name
        volumes.find { |vol| vol[:name] == name }
      else
        volumes[0]
      end
    end

    def volume_mounts(container_name = nil)
      cont = container(container_name)
      cont[:volumeMounts] ||= []
    end

    # Creates new volume without redeploy
    #
    # @param [String] volume_name Volume name
    # @param [Hash] config Volume config
    # @param [Hash] kwargs Optional arguments
    def create_volume(volume_name, config:, **kwargs)
      object = { name: volume_name }.merge(config).merge(kwargs)
      log.info "Creating volume: #{object}"
      volumes << object
    end

    # Mounts volume without redeploy
    #
    # @param [String] container_name Container's name
    # @param [String] volume_name Volume's name
    # @param [String] mount_path Mount path
    # @param [Hash] kwargs Optional arguments
    def mount_volume(container_name = nil, volume_name:, mount_path:, **kwargs)
      object = { name: volume_name, mountPath: mount_path }.merge(kwargs)
      log.info("Mounting volume: #{object}")
      volume_mounts(container_name) << object
    end
  end
end
