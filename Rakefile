# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run all specs'
Rake::TestTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

desc 'Run RuboCop on sources'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns      = ['**/*.rb']
  task.fail_on_error = false
end

task default: :test
