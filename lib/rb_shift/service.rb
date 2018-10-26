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
      log.info "Creating route #{name} #{hostname} for service #{@name}"
      if termination
        @parent.execute 'create route', termination, name,
                        hostname: hostname,
                        service: @name,
                        **opts
      else
        @parent.execute 'expose service', @name, hostname: hostname, name: name, **opts
      end
      routes true if @_routes
    end

    def ports
      @obj[:spec][:ports].each_with_object({}) { |v, h| h[v[:name].to_sym] = v }
    end

    private

    def load_routes
      items = @parent.client
                .get('routes', namespace: @parent.name)
                .select { |item| item[:spec][:to][:name] == @name }

      items.each_with_object({}) do |item, hash|
        resource            = Route.new(self, item)
        hash[resource.name] = resource
      end
    end
  end
end
