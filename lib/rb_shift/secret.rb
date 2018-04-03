# frozen_string_literal: true

require_relative 'openshift_kind'
require 'base64'

module RbShift
  # Representation of OpenShift secret
  class Secret < OpenshiftKind
    # Access value stored in secret
    #
    # @param [String] name key in Secret
    # @return [String] value associated with name
    def [](name)
      Base64.decode64(@obj[:data][name.to_sym])
    end

    # Assign value to key in secret
    #
    # @param [String] name key in Secret where value will be stored
    # @param [String] value value to be stored
    def []=(name, value)
      coded_value              = Base64.encode64(value)
      @obj[:data][name.to_sym] = coded_value
    end
  end
end
