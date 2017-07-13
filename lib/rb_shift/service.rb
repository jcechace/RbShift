# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'
require_relative 'route'

module RbShift
  # Representation of OpenShift service
  class Service < OpenshiftKind
    def routes
      @_routes ||= get_routes
    end

    def create_route(name, termination, **opts)
      @parent.execute "create route #{termination} #{name}", service: @name, **opts
      routes << @parent.client.get('routes', name: name, namespace: @parent.name) if @_routes
    end

    private

    def get_routes
      @parent
        .client
        .get('routes', namespace: @parent.name)
        .select { |item| item[:spec][:to][:name] == @name }
        .map { |item| Route.new(self, item) }
    end
  end
end
