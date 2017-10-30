# frozen_string_literal: true

require 'open3'

require_relative '../logging/logging_support'

module RbShift
  module Testing
    # Supports setup and clean up of oc cluster
    module Bootstrap
      extend Logging::LoggingSupport

      class OcClusterIsRunningError < StandardError
      end
      class InvalidCommandError < StandardError
      end

      # Setup oc cluster
      def self.setup_up
        check_oc_cluster
        log.info 'Turning up oc cluster'
        oc_cmd = "oc cluster up --host-config-dir=#{Dir.pwd}/openshift.local.config"
        execute(oc_cmd)
      end

      # Clean up oc cluster
      def self.clean_up
        log.info 'Shutting down oc cluster'
        execute 'oc cluster down'
        log.info 'Removing openshift configuration files'
        execute "sudo rm -rf #{Dir.pwd}/openshift.local.config"
      end

      private_class_method

      def self.execute(oc_cmd)
        stdout, stderr, stat = Open3.capture3(oc_cmd)
        unless stderr.empty? && stat.success?
          log.error oc_cmd
          log.error "Command failed with status #{stat.exitstatus} -->"
          log.debug "Standard  Output: #{stdout}"
          log.error "Error Output: #{stderr}"
          raise InvalidCommandError
        end
      end

      private_class_method

      def self.check_oc_cluster
        stdout_stderr, stat = Open3.capture2e('oc status')
        if stat.success?
          log.error 'OC cluster is already running'
          log.debug 'oc status'
          log.debug "Standard Output or Error output: #{stdout_stderr}"
          raise OcClusterIsRunningError
        end
      end
    end
  end
end
