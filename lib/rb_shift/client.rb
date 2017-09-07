# coding: utf-8
# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'open3'
require_relative 'project'
require_relative 'logging/logging_support'

#
# Ruby wrapper for oc tools
#
module RbShift
  # Client starting point
  class Client
    include Logging::LoggingSupport

    attr_reader :token, :url

    class InvalidAuthorizationError < StandardError; end
    class InvalidCommandError < StandardError; end

    def initialize(url, bearer_token: nil, username: nil, password: nil, verify_ssl: true)
      if bearer_token.nil? && (username.nil? || password.nil?)
        raise InvalidAuthorizationError
      end

      @token      = bearer_token || Client.get_token(url, username, password)
      @url        = url
      @kubernetes = RestClient::Resource.new "#{url}/api/v1",
                                             verify_ssl: verify_ssl,
                                             headers:    { Authorization: "Bearer #{@token}" }
      @openshift  = RestClient::Resource.new "#{url}/oapi/v1",
                                             verify_ssl: verify_ssl,
                                             headers:    { Authorization: "Bearer #{@token}" }
    end

    # @api public
    # Retrieves resources from OpenShift or kubernetes API
    #
    # @param [Class] resource Resource class
    # @param [List] opts Options
    # @option [String] namespace
    # @option [String] name Name of the resource
    # @return [List] List of resources
    def get(resource, **opts)
      request = String.new
      request << "namespaces/#{opts[:namespace]}/" if opts[:namespace]
      request << resource.to_s
      request << "/#{opts[:name]}" if opts[:name]
      client = client resource

      log.debug "Getting #{resource} from #{client}..."
      process_response JSON.parse(client[request].get, symbolize_names: true)
    end

    def read_link(link)
      v = RestClient.get "#{@url}#{link}", Authorization: "Bearer #{@token}"
      process_response JSON.parse(v, symbolize_names: true)
    end

    def process_response(response)
      return response[:items] if response[:items]
      log.debug "Response: #{response}"
      response
    end

    def create_project(name, **opts)
      log.info "Creating project #{name}"
      execute "new-project #{name}", **opts
      project = nil
      project = projects(true).find { |p| p.name == name } until project
      project
    end

    def projects(update = false)
      @_projects = load_projects if update || !@_projects
      @_projects
    end

    # rubocop:disable Metrics/AbcSize
    def execute(command, **opts)
      oc_cmd = oc_command(command, **opts)
      log.debug oc_cmd
      _, stderr, stat = Open3.capture3(oc_cmd)
      unless stderr.empty? && stat.success?
        log.error oc_command(command, exclude_token: true, **opts)
        log.error "Command failed with status #{stat.exitstatus} -->"
        log.error stderr
        raise InvalidCommandError
      end
    end

    def wait_project_deletion(project_name, timeout = 1)
      sleep timeout while get('projects').find { |v| v[:metadata][:name] == project_name }
      projects true
    end

    # rubocop:disable Metrics/LineLength
    def self.get_token(ose_server, username, password)
      `oc login #{ose_server} --username=#{username} --password=#{password} --insecure-skip-tls-verify`
      `oc whoami --show-token`.strip
    end

    protected

    def list(kind, parent)
      get(kind.resource_name, namespace: @name)
        .map { |item| resource_class.new(parent, item) }
    end

    private

    def oc_command(command, exclude_token: false, **opts)
      token = exclude_token ? '***' : @token
      "oc --server=\"#{@url}\" --token=\"#{token}\" #{command} #{unfold_opts opts}"
    end

    def client(resource)
      return @kubernetes if kube_entities.include?(resource)
      return @openshift if os_entities.include?(resource)
      raise "Resource '#{resource}' not supported!"
    end

    def load_projects
      items = get('projects')
      items.each_with_object({}) do |item, hash|
        resource            = Project.new(item[:metadata][:name], self)
        hash[resource.name] = resource
      end
    end

    def load_entities(client)
      JSON
        .parse(client.get)['resources']
        .reject { |resource| resource['name'].include?('/') }
        .map { |resource| resource['name'] }
        .uniq
    end

    def kube_entities
      @_kube_entities ||= load_entities(@kubernetes)
    end

    def os_entities
      @_os_entities ||= load_entities(@openshift)
    end

    def unfold_opts(opts)
      opts.map do |k, v|
        case v
        when Array
          v.map { |l| "--#{k}=#{l}" }.join(' ')
        when Hash
          v.map { |m, n| "--#{k}=\"#{m}=#{n}\"" }.join(' ')
        else
          "--#{k}=#{v}"
        end
      end.join(' ')
    end
  end
end
