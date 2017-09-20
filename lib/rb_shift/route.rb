# coding: utf-8
# frozen_string_literal: true

require_relative 'openshift_kind'

module RbShift
  # Representation of OpenShift route
  class Route < OpenshiftKind
    # Constructs route address
    # @return [String] address
    def address
      host        = obj[:spec][:host]
      termination = obj[:spec][:termination]
      protocol    = termination ? 'https' : 'http'
      "#{protocol}://#{host.chomp '/'}"
    end
  end
end
