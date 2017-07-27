# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'
require_relative 'route'

module RbShift
  # Representation of OpenShift service
  class Service < OpenshiftKind
    def routes(update = false)
      @_routes = load_routes if update || @_routes.nil?
      @_routes
    end

    def create_route(name, hostname, termination = 'edge', **opts)
      if termination
        @parent.execute "create route #{termination} #{name}",
                        hostname: hostname,
                        service: @name,
                        **opts
      else
        @parent.execute "expose service #{@name}", hostname: hostname, name: name, **opts
      end
      routes << @parent.client.get('routes', name: name, namespace: @parent.name) if @_routes
    end

    private

    def load_routes
      @parent
        .client
        .get('routes', namespace: @parent.name)
        .select { |item| item[:spec][:to][:name] == @name }
        .map { |item| Route.new(self, item) }
    end
  end
end
