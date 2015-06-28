#!/usr/bin/env ruby
require 'rugged'
require 'thor'
require_relative './worker.rb'

class Repo < Thor
  def initialize(initial_dir)
    @repodir = initial_dir
    @gitfile = File.expand_path(".git", @current_dir)
  end

#class initializers
  def self.init_at(dir)
    result = Repo.new(dir)
    unless result.exists_on_disk?
      Rugged::Repository.init_at(@repodir)
    end
    result
  end

  def self.lowest(dir)
    res_dir = dir
    loop do
      break if contains_gitfile?(res_dir) or res_dir == "/"
      res_dir = File.dirname(res_dir)
    end
    Repo.new(res_dir) if contains_gitfile?(res_dir)
  else
    nil
  end

  def self.highest(dir)
    res_dir = dir
    cur_dir = dir
    loop do
      cur_dir = File.dirname(res_dir)
      res_dir = cur_dir if contains_gitfile?(cur_dir) else res_dir
      break if cur_dir = "/"
    end
  end

  def stage_files(files)
    files
        .group_by { |file| File.dirname(file) }
        .each { |dir, files| stage_files_in(dir, files) }
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

#convenience_methods?
  def exists_on_disk?
    File.exist?(@gitfile)
  end

  def contains_gitfile?(dir)
    File.exist?(File.expand_path(".git", dir))
  end

  def refers_to_file?(thing)
    relative_file = File.exist?(File.expand_path(thing, @current_dir))
    absolute_file = File.exist?(File.absolute_path(thing))
    relative_file or absolute_file
  end

  def fetch_just_me

  end

end
