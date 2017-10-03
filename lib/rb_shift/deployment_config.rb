# coding: utf-8
# frozen_string_literal: true

require 'timeout'

require_relative 'openshift_kind'
require_relative 'replication_controller'

module RbShift
  # Representation of OpenShift deployment config
  class DeploymentConfig < OpenshiftKind
    def scale(replicas)
      log.info "Scaling deployment from deployment config #{name} to #{replicas} replicas"
      @parent.execute "scale dc #{name}", replicas: replicas
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
          break unless running?
        end
      end
      log.info 'Deployments finished'
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

    # Lists environment variables
    #
    # @param [String, nil] container Name of the container or nil for arbitrary container
    # @return [Hash] A hash of environment variables
    def env_variables(container = nil)
      unless @_env
        containers = @obj[:spec][:template][:spec][:containers]
        cont       = containers.find { |c| container.nil? || c[:name] == container }
        @_env      = cont[:env].each_with_object({}) do |var, env|
          env[var[:name]] = var[:value]
        end
      end
      @_env
    end

    # Sets environment variables
    # Using nil as a value will unset that variable
    #
    # @param [String, nil] container Name of the container where the environment is set
    # @param [Bool] block If true blocks until redeployment is finished
    # @param [Fixnum] timeout Maximum time to wait
    # @param [Fixnum] polling State checking period
    # @param [Hash] env Environment variables
    def set_env_variables(container = nil, block: false, timeout: 60, polling: 5,  **env)
      env_string  = env.map { |k, v|  v ? "#{k}=#{v}" : "#{k}-" }.join(' ')
      container ||= @obj[:spec][:template][:spec][:containers][0][:name]
      log.info "Setting env variables (#{env_string}) for #{name}/#{container}"
      @parent.execute("env dc/#{container} #{env_string}")
      sleep polling
      wait_for_deployments(timeout: timeout, polling: polling) if block
      reload(true)
      @_env = nil
    end
  end
end
