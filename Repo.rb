#!/usr/bin/env ruby
require 'rugged'
require 'thor'


class Repo < Thor
  desc "add", "Add file contents to the index"
  def add
    current_directory = Dir.pwd
    repo_file = File.expand_path("/.repo", Dir.pwd)
    print(File.exist?(repo_file))
  end

end

Repo.start
