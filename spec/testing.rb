# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/hooks/default'

require_relative 'testing/rb_shift_spec'

module RbShift
  # Testing module
  module Testing
  end
end

MiniTest::Spec.register_spec_type(//, RbShift::Testing::RbShiftSpec)
