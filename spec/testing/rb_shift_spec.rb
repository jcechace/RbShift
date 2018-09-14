# frozen_string_literal: true

require 'uri'
require 'rb_shift/client'

module RbShift
  module Testing
    # Extension of the Minitest
    class RbShiftSpec < Minitest::HooksSpec
      # Initializes test
      #
      # @param [String, Symbol] name test name
      def initialize(name)
        super
        @client = RbShift::Client.new 'https://127.0.0.1:8443',
                                      username:   :admin,
                                      password:   :admin,
                                      verify_ssl: false
      end
    end
  end
end
