# frozen_string_literal: true

require 'rb_shift/testing'

describe 'When RbShift is using client' do
  before(:all) do
    @project = create_project 'project'
    @project2 = create_project 'project2'
  end

  let(:projects) { @client.projects true }

  it 'will create project successfully' do
    @project.name.must_equal 'project'
    projects.must_include @project.name
  end

  it 'will delete project successfully' do
    @project2.delete true

    projects.wont_include @project2.name
  end

  after(:all) do
    @project.delete true
  end

  private

  # Create new project
  # @param [String] name Name of project
  # @return [RbShift::Project] created Project
  def create_project(name)
    @client.create_project name
  end
end
