# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'
require_relative 'config_map'
require_relative 'deployment_config'
require_relative 'pod'
require_relative 'secret'
require_relative 'service'
require_relative 'template'

module RbShift
  # Representation of OpenShift project
  class Project < OpenshiftKind
    attr_reader :name, :client

    def self.open(name, client)
      Project.new(name, client)
    end

    def pods(update = false)
      @_pods = init_objects(Pod) if update || @_pods.nil?
      @_pods
    end

    def deployment_configs(update = false)
      @_deployment_configs = init_objects(DeploymentConfig) if update || @_deployment_configs.nil?
      @_deployment_configs
    end

    def services(update = false)
      @_services = init_objects(Service) if update || @_services.nil?
      @_services
    end

    def secrets(update = false)
      @_secrets = init_objects(Secret) if update || @_services.nil?
      @_secrets
    end

    def config_maps(update = false)
      @_config_maps = init_objects(ConfigMap) if update || @_services.nil?
      @_config_maps
    end

    def templates(update = false)
      @_templates = init_objects(Template) if update || @_templates.nil?
      @_templates
    end

    def create_secret(name, kind, **opts)
      execute "create secret #{kind} #{name}", **opts
      secrets << @client.get('secrets', name: name, namespace: @name) if @_secrets
    end

    def create_template(file)
      execute "create -f \"#{file}\""
      templates << @client.get('templates', name: name, namespace: @name) if @_templates
    end

    def create_config_map(name, source, path, **opts)
      execute "create configmap #{name}", source.to_sym => path, **opts
      config_maps << @client.get('configmaps', name: name, namespace: @name) if @_config_maps
    end

    def create_service(name, kind, **opts)
      execute "create service #{kind} #{name}", **opts
      services << @client.get('services', name: name, namespace: @name) if @_services
    end

    def delete(block = false, timeout = 1)
      execute "delete project #{@name}"
      @client.wait_project_deletion(@name, timeout) if block
    end

    def wait_for_deployments(timeout = 30, update = false)
      deployment_configs true
      wait = true
      while wait
        sleep timeout
        wait = !deployment_configs(update).select(&:running?).empty?
      end
    end

    # Creates new Openshift application
    # Params:
    # +params+ - hash of key-value pairs to set/override a parameter value in the template
    # +args+ - any desired custom OC command options
    def new_app(source, path, block = false, timeout = 30, **opts)
      execute 'new-app ', source.to_sym => path, **opts
      wait_for_deployments timeout if block
      invalidate unless block
    end

    def execute(command, **opts)
      @client.execute command, namespace: @name, **opts
    end

    def read_link(link)
      @client.read_link link
    end

    private

    def init_objects(klass)
      resource_class = Object.const_get(klass.name)
      @client
        .get(resource_class.resource_name, namespace: @name)
        .map { |item| resource_class.new(self, item) }
    end

    def initialize(name, client)
      @client = client
      @obj    = @client.get('namespaces', name: name)
      @name   = name
    end
  end
end
