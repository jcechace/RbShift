# coding: utf-8
# frozen_string_literal: true

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
      @_secrets = init_objects(Secret) if update || @_secrets.nil?
      @_secrets
    end

    def config_maps(update = false)
      @_config_maps = init_objects(ConfigMap) if update || @_config_maps.nil?
      @_config_maps
    end

    def templates(update = false)
      @_templates = init_objects(Template) if update || @_templates.nil?
      @_templates
    end

    def role_bindings(update = false)
      @_role_bindings = init_objects(RoleBinding) if update || @_role_bindings.nil?
      @_role_bindings
    end

    def routes(update = false)
      @_routes = init_objects(Route) if update || @_routes.nil?
      @_routes
    end

    def create_secret(name, kind, files: nil, literals: nil, **opts)
      log.info "Creating secret #{kind} #{name} in project #{@name}"
      execute "create secret #{kind} #{name}", 'from-file': files, 'from-literal': literals, **opts
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

    def create_config_map(name, files: nil, literals: nil, **opts)
      log.info "Creating config map #{name} in project #{@name}"
      execute "create configmap #{name}", 'from-file': files, 'from-literal': literals, **opts
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

    # Deletes all resources by label
    #
    # @param [String] label_name name of label in selector
    # @param [String] label_value value of label in selector
    def delete_by_label(label_name, label_value)
      log.info "Deleting all resources with #{label_name} label set to #{label_value}"
      @client.execute 'delete all', selector: "#{label_name}=#{label_value}"
      invalidate
    end

    def wait_for_deployments(timeout = 30, update = false)
      deployment_configs true
      wait = true
      while wait
        log.debug "Waiting for deployments for #{timeout} seconds..."
        sleep timeout
        wait = !deployment_configs(update).values.select(&:running?).empty?
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
      invalidate
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
