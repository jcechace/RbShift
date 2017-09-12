# coding: utf-8
# frozen_string_literal: true

require_relative 'core_extensions'
require_relative 'openshift_kind'
require_relative 'config_map'
require_relative 'deployment_config'
require_relative 'pod'
require_relative 'secret'
require_relative 'service'
require_relative 'template'
require_relative 'role_binding'

module RbShift
  # Representation of OpenShift project
  class Project < OpenshiftKind
    attr_reader :name, :client

    resource Pod, :pods
    resource DeploymentConfig, :deployment_configs
    resource Secret, :secrets
    resource Service, :services
    resource ConfigMap, :config_maps
    resource Template, :templates
    resource RoleBinding, :role_bindings
    resource Route, :routes

    def create_secret(name, kind, **opts)
      log.info "Creating secret #{kind} #{name} in project #{@name}"
      execute "create secret #{kind} #{name}", **opts
      secrets true if @_secrets
    end

    def add_role_to_user(role, username)
      log.info "Adding role #{role} to user #{username} in project #{@name}"
      execute "policy add-role-to-user #{role} #{username}"
      role_bindings true if @_role_bindings
    end

    def add_role_to_group(role, groupname)
      log.info "Adding role #{role} to user #{groupname} in project #{@name}"
      execute "policy add-role-to-group #{role} #{groupname}"
      role_bindings true if @_role_bindings
    end

    def create_template(file)
      log.info "Creating template from file #{file} in project #{@name}"
      execute "create -f \"#{file}\""
      templates true if @_templates
    end

    def create_config_map(name, source, path, **opts)
      log.info "Creating config map #{name} in project #{@name}"
      execute "create configmap #{name}", source.to_sym => path, **opts
      config_maps true if @_config_maps
    end

    def create_service(name, kind, **opts)
      log.info "Creating service #{kind} #{name} in project #{@name}"
      execute "create service #{kind} #{name}", **opts
      services true if @_services
    end

    def delete(block = false, timeout = 1)
      log.info "Deleting project #{@name}"
      execute "delete project #{@name}"
      @client.wait_project_deletion(@name, timeout) if block
    end

    def wait_for_deployments(timeout = 30, update = false)
      deployment_configs true
      wait = true
      while wait
        log.debug "Waiting for deployments for #{timeout} seconds..."
        sleep timeout
        wait = !deployment_configs(update).select(&:running?).empty?
      end
      log.info 'Deployments finished'
    end

    # Creates new Openshift application
    # Params:
    # +params+ - hash of key-value pairs to set/override a parameter value in the template
    # +args+ - any desired custom OC command options
    def new_app(source, path, block = false, timeout = 30, **opts)
      log.info "Creating Openshift application #{source} #{path} in project #{@name}"
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

    protected

    attr_writer :obj

    def obj
      @obj ||= @client.get('namespaces', name: @name)
    end

    private

    # Initialize object representations of OpenShift/Kubernetes resources
    #
    # @return [Hash] Name-Object hash of resource object
    def init_objects(klass)
      rclass = Object.const_get(klass.name)
      items  = @client.get(rclass.resource_name, namespace: @name)
      items.each_with_object({}) do |item, hash|
        resource            = rclass.new(self, item)
        hash[resource.name] = resource
      end
    end

    def initialize(name, client)
      @client = client
      @name   = name
    end
  end
end
