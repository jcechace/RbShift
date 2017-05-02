require 'rest-client'
require 'json'
require_relative 'project'

module RbShift
  class Client
    attr_reader :token, :url

    def initialize(url, bearer_token)
      @token      = bearer_token
      @url        = url
      @kubernetes = RestClient::Resource.new "#{url}/api/v1",
                                             verify_ssl: OpenSSL::SSL::VERIFY_NONE,
                                             headers:    { Authorization: "Bearer #{bearer_token}" }
      @openshift  = RestClient::Resource.new "#{url}/oapi/v1",
                                             verify_ssl: OpenSSL::SSL::VERIFY_NONE,
                                             headers:    { Authorization: "Bearer #{bearer_token}" }
      @_projects  = Project.list
    end

    def get(resource, **opts)
      request = ''
      request << "namespaces/#{opts[:namespace]}/" if opts[:namespace]
      request << "#{resource}/"
      request << "#{opts[:name]}" if opts[:name]
      client = client resource
      process_response JSON.parse(client[request].get, :symbolize_names => true)
    end

    def process_response(response)
      return response[:items] if response[:items]
      return response[:metadata] if response[:metadata]
    end

    def create_project(name, **opts)
      `oc new-project #{name}`
    end

    protected

    def list(kind, parent)
      get(kind.resource_name, namespace: @name)
        .map { |item| resource_class.new(parent, item) }
    end

    def self.list(service)
      project.client
        .get('routes', namespace: project.name)
        .select { |item| item[:spec][:to][:name] == service.name }
        .map { |item| kind.new(parent, item) }
    end

    private

    def client(resource)
      return @kubernetes if kube_entities.include?(resource)
      return @openshift if os_entities.include?(resource)
      raise "Resource '#{resource}' not supported!"
    end

    def load_entities(client)
      JSON
        .parse(client.get)['resources']
        .select { |resource| !resource['name'].include?('/') }
        .map { |resource| resource['name'] }
        .uniq
    end

    def kube_entities
      @_kube_entities ||= load_entities(@kubernetes)
    end

    def os_entities
      @_os_entities ||= load_entities(@openshift)
    end
  end
end

