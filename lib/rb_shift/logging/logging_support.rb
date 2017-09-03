# coding: utf-8
# frozen_string_literal: true

require 'logger'

module Logging
  # Custom logging module
  module LoggingSupport
    # @api public
    # Logger instance
    #
    # @return [Logger] Logger
    def log
      cls_name  = Logging::LoggingSupport.get_class_name self
      @logger ||= Logging::LoggingSupport.get_logger(log_level: log_level, name: cls_name)
    end

    def log_level
      ENV['RB_SHIFT_LOG_LEVEL'] || 'info'
    end

    # Returns class name without module
    #
    # @param [Class] klass Class instance
    # @return [String] class name without modules
    def self.get_class_name(klass)
      klass.class.name.split('::').last
    end

    # @api public
    # Creates a instance of logger using in config information
    #
    # @param [String] log_level Override default log level using in config or ENV
    # @return [Logger] Logger instance
    def self.get_logger(log_level: 'info', name: nil)
      log          = Logger.new(STDERR)
      log.progname = name if name
      log.level    = get_level log_level
      logging_format log
    end

    # @api public
    # Gets logging logging level number
    #
    # @param [String] log_level Logging level as string is 'debug'
    # @return [Fixnum] Log level id
    def self.get_level(log_level = 'debug')
      Logger.const_get log_level.upcase
    rescue NameError
      Logger::DEBUG
    end

    # Sets logging format for specified logger
    #
    # @param [Logger] logger Logger for which the formatter will be set
    # @return [Logger] modified logger instance
    def self.logging_format(logger)
      default_formatter = Logger::Formatter.new
      logger.formatter  = proc do |severity, datetime, progname, msg|
        default_formatter.call(severity, datetime, "(#{progname})", msg.dump)
      end
      logger
    end
  end
end
