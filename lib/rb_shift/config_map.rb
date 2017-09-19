# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'

module RbShift
  # Representation of ConfigMap
  class ConfigMap < OpenshiftKind
    # Access the values contained by ConfigMap
    #
    # @param [String] name name of key in ConfigMap
    # @return [String] returns associated value
    def [](name)
      @obj[:data][name.to_sym]
    end

    # Assign value to key in ConfigMap
    #
    # @param [String] name key in ConfigMap to be changed
    # @param [String] value value to be stored in ConfigMap
    def []=(name, value)
      @obj[:data][name.to_sym] = value
    end
  end
end
