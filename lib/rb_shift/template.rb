# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'

module RbShift
  # Representation of OpenShift template
  class Template < OpenshiftKind
    # Processes the template
    # Params:
    # +params+ - hash of key-value pairs to set/override a parameter value in the template
    # +args+ - any desired custom OC command options
    def process(params = {}, **opts)
      @parent.execute "process #{name}", value: params, **opts
      @parent.invalidate
    end
  end
end
