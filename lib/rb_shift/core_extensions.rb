# coding: utf-8
# frozen_string_literal: true

module RbShift
  module CoreExtensions
    # Extension methods for Class class
    module Class
      def resource(type, name)
        define_method(name) do |update = false|
          var      = "@_#{name}"
          resource = instance_variable_get var
          if update || resource.nil?
            resource = init_objects(type)
            instance_variable_set var, resource
          end
          resource
        end
      end
    end
  end
end

Class.include RbShift::CoreExtensions::Class
