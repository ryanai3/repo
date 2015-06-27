#!/usr/bin/env ruby
require 'rugged'
require 'thor'
require_relative './worker.rb'

class Repo < Thor
  def initialize(initial_dir)
    @repodir = initial_dir
    @gitfile = File.expand_path(".git", @current_dir)
  end

  def self.init_at(dir)
    result = Repo.new(dir)
    unless result.exists_on_disk?
      Rugged::Repository.init_at(@repodir)
    end
    result
  end

  def exists_on_disk?
    File.exist?(@gitfile)
  end

  def stage_files(files)
    files.group_by { |file| File.dirname(file) }.each { |dir, files| stage_files_in(dir, files) }
  end

  def stage_files_in(dir, files)
    repo = Rugged::Repository.discover(File.join(dir, ".blah"))
    index = repo.index
    #index is the index we want to stage the files into!
    files.each { |file| index << File.path(file) }
    index.write
  end

  def system_call_git(*args)
    args_string = args.map { |i| i.to_s }.join(" ")
    system('git ' + args_string)
  end

  def refers_to_file?(thing)
    relative_file = File.exist?(File.expand_path(thing, @current_dir))
    absolute_file = File.exist?(File.absolute_path(thing))
    relative_file or absolute_file
  end

  def repofile2gitfile
    File.rename(@repofile, @gitfile)
  end

  def gitfile2repofile
    File.rename(@gitfile, @repofile)
  end

  def safe_repofile2gitfile
    if File.exist?(repofile)
      repofile2gitfile
    end
  end

  def safe_gitfile2repofile
    if File.exist?(current_gitfile)
      gitfile2repofile
    end
  end
end
