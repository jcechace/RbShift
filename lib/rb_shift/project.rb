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

    def pods
      @_pods ||= init_objects(Pod)
    end

    def deployment_configs
      @_deployment_configs ||= init_objects(DeploymentConfig)
    end

    def services
      @_services ||= init_objects(Service)
    end

    def secrets
      @_secrets ||= init_objects(Secret)
    end

    def config_maps
      @_config_maps ||= init_objects(ConfigMap)
    end

    def templates
      @_templates ||= init_objects(Template)
    end

    def create_secret(name, kind, **opts)
      `oc secrets #{kind} #{name} #{unfold_params(opts)}`
      secrets << @client.get('secrets', :name => name, :namespace => @name) if @_secrets
    end

    def create_template(file)
      `oc create -f #{file}`
      templates << @client.get('templates', :name => name, :namespace => @name) if @_templates
    end

    def create_config_map(name, source, path, **opts)
      `oc create configmap #{name} --#{source}=#{path} #{unfold_params(opts)}`
      config_maps << @client.get('configmaps', :name => name, :namespace => @name) if @_config_maps
    end

    def create_service(name, kind, **opts)
      `oc create service #{kind} #{name} #{unfold_params(opts)}`
      services << @client.get('services', :name => name, :namespace => @name) if @_services
    end

    # Creates new Openshift application
    # Params:
    # +params+ - hash of key-value pairs to set/override a parameter value in the template
    # +args+ - any desired custom OC command options
    def new_app(source, path, params = {}, **opts)
      `oc new-app --#{source}=#{path} #{unfold_params(opts)} #{unfold_params(params, 'param')}`
      invalidate
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
      @obj    = @client.get('namespaces', :name => name)
      @name   = name
      `oc login #{client.url} --token=#{client.token}`
      `oc project #{name}`
    end
  end
end
