# frozen_string_literal: true

module RbShift
  # Representation of OpenShift Metadata object
  class Metadata
    EMPTY_HASH = {}.freeze
    private_constant :EMPTY_HASH

    def initialize(metadata)
      @metadata = metadata
    end

    def name
      @metadata[__method__]
    end

    def namespace
      @metadata[__method__]
    end

    def labels
      @metadata[__method__] || EMPTY_HASH
    end

    def annotations
      @metadata[__method__] || EMPTY_HASH
    end

    def respond_to_missing?(method, *)
      @metadata.key?(method) || super
    end

    def method_missing(method)
      @metadata.fetch(method)
    rescue KeyError
      super
    end
  end
end
