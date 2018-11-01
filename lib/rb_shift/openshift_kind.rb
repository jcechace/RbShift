# frozen_string_literal: true

require 'json'
require_relative 'logging/logging_support'
require 'shellwords'
require 'forwardable'
require_relative 'metadata'

module RbShift
  # Abstract parent for all OpenShift resources (kinds)
  class OpenshiftKind
    include Logging::LoggingSupport
    extend Forwardable

    attr_reader :metadata
    def_delegators :metadata, :name, :namespace

    def initialize(parent, obj)
      @parent    = parent
      @metadata  = Metadata.new(obj[:metadata])
      @obj       = obj
    end

    def method_missing(symbol, *args)
      return obj.send(symbol, *args) if obj.respond_to? symbol

      super
    end

    def respond_to_missing?(symbol)
      obj.respond_to? symbol
    end

    def reload(self_only = false)
      self.obj = read_link obj[:metadata][:selfLink]
      invalidate unless self_only
    end

    def update(patch = nil)
      if patch
        parent.invalidate
      else
        patch = obj.to_json
      end

      log.info "Updating #{self.class.class_name} #{name}"
      @parent.execute 'patch', self.class.class_name, name, "-p #{patch}"
    end

    def execute(command, *args, **opts)
      @parent.execute(command, *args, **opts) if @parent.respond_to? :execute
    end

    def delete
      log.info "Deleting #{self.class.class_name} #{name}"
      @parent.execute 'delete', self.class.class_name, name
      @parent.invalidate if @parent.respond_to? :invalidate
    end

    def invalidate
      instance_variables.select { |x| x.to_s.include?('@_') }.each do |x|
        instance_variable_set(x, nil)
      end
    end

    def self.resource_name
      class_name + 's'
    end

    def self.class_name
      name.split('::').last.downcase
    end

    def read_link(link)
      @parent.read_link link
    end

    protected

    attr_accessor :obj
  end
end
