# coding: utf-8
# frozen_string_literal: true

require 'json'
require_relative 'logging/logging_support'


module RbShift
  # Abstract parent for all OpenShift resources (kinds)
  class OpenshiftKind
	include Logging::LoggingSupport	  
    attr_reader :name

    def initialize(parent, obj)
      @parent = parent
      @name   = obj[:metadata][:name]
      @obj    = obj
    end

    def method_missing(symbol, *args)
      return obj.send(symbol, *args) if obj.respond_to? symbol
      super
    end

    def respond_to_missing?(symbol)
      obj.respond_to? symbol
    end

    def reload
      self.obj = read_link obj[:metadata][:selfLink]
      invalidate
    end

    def update(patch = nil)
      if patch
        parent.invalidate
      else
        patch = obj.to_json
      end

      log.info "Updating #{self.class.class_name} #{@name}"
      @parent.execute "patch #{self.class.class_name} #{@name} -p '#{patch}"
    end

    def execute(command, **opts)
      @parent.execute(command, **opts) if @parent.respond_to? :execute
    end

    def delete
      log.info "Deleting #{self.class.class_name} #{@name}"
      @parent.execute "delete #{self.class.class_name} #{@name}"
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
