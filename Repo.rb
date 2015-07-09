#!/usr/bin/env ruby
require 'rugged'
require 'thor'
require_relative './worker.rb'
require 'json'

class Repo
  def initialize(dir, subrepos, isHead = false)
    @location = dir
    @subrepos = subrepos
    @gitfile = File.expand_path(".git", @location)
    @gitrepo = Rugged::Repository.new(@location)
    @repofile = File.expand_path(".repo", @location)
    @isHead = isHead
  end

#class initializers
  def self.init_at(dir)
    unless contains_gitfile?(dir)
     Rugged::Repository.init_at(dir)
    end
    Repo.from_dir(dir)
  end

  def self.lowest_above(dir)
    res_dir = dir
    loop do
      break if is_repo_dir?(res_dir) or res_dir == "/"
      res_dir = File.dirname(res_dir)
    end
    Repo.from_dir(res_dir) if is_repo_dir?(res_dir)
  else
    nil
  end

  def self.highest_above(dir)
    res_dir = dir
    cur_dir = dir
    loop do
      cur_dir = File.dirname(res_dir)
      if is_repo_dir?(cur_dir)
        res_dir = cur_dir
        end
      break if cur_dir = "/"
    end
    Repo.from_dir(res_dir)
  end

  def self.from_repoInfo(repoInfo)
    subRepos = repoInfo.subrepos.map(&:from_repoInfo)
    Repo.new(repoInfo.path_to, repoInfo.subrepos, repoInfo.isHead)
  end

  def self.from_dir(dir)
    self.from_repoInfo(RepoInfo.from_json(File.expand_path(".repo", dir)))
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

  def diff(*args)
    result = with_captured_stdout{@gitrepo.diff}
  end

#convenience_methods?
  def exists_on_disk?
    File.exist?(@gitfile)
  end

  def self.contains_gitfile?(dir)
    File.exist?(File.expand_path(".git", dir))
  end

  def self.is_repo_dir?(dir)
    contains_gitfile?(dir) and File.exist?(File.expand_path(".repo", dir))
  end

  def self.refers_to_file?(thing)
    relative_file = File.exist?(File.expand_path(thing, @current_dir))
    absolute_file = File.exist?(File.absolute_path(thing))
    relative_file or absolute_file
  end

  def fetch_just_me(*args)
    system_call_git('fetch', args)
  end

  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('','w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end
end

class RepoInfo
  def initialize(path_to, subrepos = [], isHead = true)
    @path_to = path_to
    @subrepos = subrepos
    @isHead = isHead
  end

  def to_hash
    subrepos_hash = subrepos.map(&:to_hash)
    {"path_to" => @path_to,
     "subrepos" => subrepos_hash,
     "isHead" => isHead}
  end

  def to_json
    to_hash.to_json
  end

  def self.from_json(string)
    data = JSON.load(string)
    subrepos = data["subrepos"].map(&:from_json)
    self.new(
        data["path_to"],
        subrepos,
        data["isHead"]
    )
  end
end