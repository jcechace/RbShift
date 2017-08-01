# coding: utf-8
# frozen_string_literal: true

require 'rest-client'
require 'json'
require_relative 'project'

#
# Ruby wrapper for oc tools
#
module RbShift
  # Client starting point
  class Client
    attr_reader :token, :url

    def initialize(url, bearer_token = nil, username = nil, password = nil)
      if bearer_token.nil? && (username.nil? || password.nil?)
        raise 'Token or username and password must be provided'
      end

      @token      = get_token(url, username, password) unless bearer_token
      @token      = bearer_token if bearer_token
      @url        = url
      @kubernetes = RestClient::Resource.new "#{url}/api/v1",
                                             verify_ssl: OpenSSL::SSL::VERIFY_NONE,
                                             headers:    { Authorization: "Bearer #{bearer_token}" }
      @openshift  = RestClient::Resource.new "#{url}/oapi/v1",
                                             verify_ssl: OpenSSL::SSL::VERIFY_NONE,
                                             headers:    { Authorization: "Bearer #{bearer_token}" }
    end

    # rubocop:disable Metrics/AbcSize
    def get(resource, **opts)
      request = String.new
      request << "namespaces/#{opts[:namespace]}/" if opts[:namespace]
      request << resource.to_s
      request << "/#{opts[:name]}" if opts[:name]
      client = client resource
      process_response JSON.parse(client[request].get, symbolize_names: true)
    end

    def read_link(link)
      v = RestClient.get "#{@url}#{link}", Authorization: "Bearer #{@token}"
      process_response JSON.parse(v, symbolize_names: true)
    end

    def process_response(response)
      return response[:items] if response[:items]
      response
    end

    def create_project(name, **opts)
      execute "new-project #{name}", **opts
      project = nil
      project = projects(true).find { |p| p.name == name } while project.nil?
      project
    end

    def projects(update = false)
      @_projects = load_projects if update || !@_projects
      @_projects
    end

    def execute(command, **opts)
      `oc --server="#{@url}" --token="#{@token}" #{command}  #{unfold_opts opts}`
    end

    def wait_project_deletion(project_name, timeout = 1)
      sleep timeout until projects(true).find { |v| v.name == project_name }.nil?
    end

    # rubocop:disable Metrics/LineLength
    def self.get_token(ose_server, username, password)
      `oc login #{ose_server} --username=#{username} --password=#{password} --insecure-skip-tls-verify`
      `oc whoami --show-token`.strip
    end

    def self.list(service)
      Project
        .client
        .get('routes', namespace: project.name)
        .select { |item| item[:spec][:to][:name] == service.name }
        .map { |item| kind.new(parent, item) }
    end

    protected

    def list(kind, parent)
      get(kind.resource_name, namespace: @name)
        .map { |item| resource_class.new(parent, item) }
    end

    private

    def client(resource)
      return @kubernetes if kube_entities.include?(resource)
      return @openshift if os_entities.include?(resource)
      raise "Resource '#{resource}' not supported!"
    end

    def load_projects
      get('projects').map { |it| Project.new(it[:metadata][:name], self) }
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
