#!/usr/bin/env ruby
require 'rugged'
require 'git'
require 'thor'
require 'json'

class Repo
  def initialize(dir, subrepos, is_head = false, bindings)
    @location = dir
    @subrepos = subrepos
    @gitfile = File.expand_path(".git", @location)
    @gitrepo = Git.init(@location)
    @repofile = File.expand_path(".repo", @location)
    @is_head = is_head
    @bindings = bindings
  end


#class initializers

  # Initializes/Re-initializes an Rgit repo in a directory
  def self.init(dir, options = {})
    # 1. Initialize a git repository in the directory
    Git.init(dir, options)
    # 2. Initialize a repo object w/ associated .repo file from that dir
    create_from_git(dir)
  end

  # Initialize/Re-initialize a repo object w/ associated .repo from
  # a dir containing a .git
  def self.init_from_git(dir)
    # 1. Find parent if it exists - !! converts truthy/falsey to a boolean
    parent_exists = !!lowest_above(File.dirname(@location))
    # 2. Create a .repo file and write it to disk
    #    Creating Repo object doesn't handle that
    repo_info = RepoInfo.new(
      path_to = dir,
      subrepos = [],
      is_head = parent_exists
    )
    repo_info.write_to_disk!
    # 3. Create Repo object from the repoInfo, return it
    from_repo_info(repo_info)
  end

  def self.create_at(dir)
    unless contains_gitfile?(dir)
      Rugged::Repository.create_at(dir)
    end
    Repo.from_dir(dir)
  end

  def self.lowest_above(dir)
    res_dir = dir
    loop do
      break if is_repo_dir?(res_dir) or res_dir == "/"
      res_dir = File.dirname(res_dir)
    end
    is_repo_dir?(res_dir) ? Repo.from_dir(res_dir) : nil
  end

  def self.highest_above(dir)
    cur_dir = dir
    res_dir = dir
    while (cur_dir != "/")
      if is_repo_dir?(cur_dir)
        res_dir = cur_dir
      end
      cur_dir = File.dirname(cur_dir)
    end

    Repo.from_dir(res_dir)
  end

  def self.from_repo_info(repo_info)
    subs = repo_info.subrepos
    subRepos = subs.map(&:from_repo_info)
    Repo.new(
      repo_info.path_to,
      repo_info.subrepos,
      repo_info.is_head,
      repo_info.bindings
    )
  end

  def self.from_dir(dir)
    self.from_repo_info(RepoInfo.from_json(File.expand_path(".repo", dir)))
  end

#convertersz
  def to_repoinfo
    RepoInfo.new(@location, @subrepos, @is_head, @bindings)
  end

#save_methods
  def save_to_disk
    repoInfo = to_repoinfo
    File.write(@repofile, repoInfo.to_json)
  end

#api_methods
  def add(files, options)
    files_in_repo, files_in_sub_repos = files
      .group_by { |file| File.dirname(file)}
      .partition{ |k, v| k == @location}
    container_add(files_in_repo.to_h.values, options)
    @subrepos.each {|subrepo| add(files_in_sub_repos.to_h.values, options)}
  end

#methods
  def init_git
    system_call_git()
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
    result = with_captured_stdout { @gitrepo.diff }
  end

  def commit(*args)
    #TODO
  end

#container_methods
  def container_add(files, options)
    #index is the index we want to stage the files into!
    @gitrepo.add(files, options)
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
      $stdout = StringIO.new('', 'w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  def capture_pty_stdout(cmd)
    result = ''
    PTY.spawn(cmd) do |stdout, stdin, pid|
      begin
        stdout.each { |line| result += line }
      rescue Errno::EIO #Done getting output
        result
      end
    end
    result
  end

  def pretty_page_command_to_user(cmd)
    begin
      PTY.spawn(cmd) do |stdout, stdin, pid|
        begin
          stdout.each { |line| puts line }
        end
      end
    rescue PTY::ChildExited
      #done, return control
    end
  end

  def pending_commits?
    @gitrepo.index.count > 0
  end

  def num_independent_pending_commits
    (pending_commits? ? 1 : 0) + @subrepos.each{ |subrepo| subrepo.num_independent_pending_commits}
  end

end

class RepoInfo
  attr_reader :path_to, :subrepos, :is_head, :bindings

  def initialize(path_to, subrepos = [], is_head = true, bindings = {})
    @path_to = path_to
    @subrepos = subrepos
    @is_head = is_head
    @bindings = bindings
  end

  def to_hash
    subrepos_hash = subrepos.map(&:to_hash)
    {"path_to" => @path_to,
     "subrepos" => subrepos_hash,
     "isHead" => isHead,
     "bindings" => bindings}
  end

  def to_json
    to_hash.to_json
  end

  def write_to_disk!
    File.open(@path_to){ |f| f << to_json }
  end

  #class initializers
  def self.from_json(string)
    file = File.read(string)
    data = JSON.parse(file)
    subrepos = data["subrepos"].map(&:from_json)
    self.new(
        data["path_to"],
        subrepos,
        data["isHead"],
        data["bindings"]
    )
  end
end