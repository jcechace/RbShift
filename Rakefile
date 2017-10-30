# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'
require 'rb_shift/testing/bootstrap'

desc 'Run all specs'
Rake::TestTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

desc 'Run RuboCop on sources'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns      = ['**/*.rb']
  task.fail_on_error = false
end

desc 'Setup oc cluster'
task :setup do
  RbShift::Testing::Bootstrap.setup_up
end

desc 'Clean up oc cluster'
task :clean_up do
  RbShift::Testing::Bootstrap.clean_up
end

task default: :test

task all_in_one: [:setup, :test, :clean_up]
