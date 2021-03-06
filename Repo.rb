#!/usr/bin/env ruby
require 'rugged'
require 'git'
require 'thor'
require 'json'
require 'pathname'

class Repo
  attr_accessor :location, :url, :subrepos, :is_head
  def initialize(dir, subrepos, is_head = false)
    @location = dir
    @url = "www.google.com" #TODO: GET URL FROM GIT
    @subrepos = subrepos
    @gitfile = @location + ".git"
    @gitrepo = Rugged::Repository.new(@location.realpath)
    @repofile = @location + ".repo" 
    @is_head = is_head
  end

  #class initializers

  # Initializes/Re-initializes an Rgit repo in a directory
  def self.init(dir, opt_str)
    # 1. Initialize a git repository in the directory
    output = git_command('init', opt_str, dir)
    # 2. Initialize a repo object w/ associated .repo file from that dir
    init_from_git(dir)
  end

  # Initialize/Re-initialize a repo object w/ associated .repo from
  # a dir containing a .git
  def self.init_from_git(dir)
    # 1. Find parent if it exists - !! converts truthy/falsey to a boolean
    parent_exists = !!lowest_above(dir)
    # 2. Create a .repo file and write it to disk
    #    Creating Repo object doesn't handle that
    repo_info = RepoInfo.new(
      path_to: dir + ".repo",
      url: "www.google.com", #TODO: GET URL FROM GIT
      subrepos: [],
      is_head: parent_exists
    )
    repo_info.write_to_disk!
  end

  # Clone a rgit repository and it's subrepos recursively into the passed
  # directory, with the passed options as a string to git
  # Return an object representing the Rgit repository
  def self.clone(repository, directory, opt_str)
    git_command('clone', "#{opt_str} #{repository}", directory)
    result = from_dir(directory)
    result.subrepos = result.subrepos.map { |sub|
      clone(
        sub.url,
        directory + sub.path_to,
        opt_str,
      )
    }
  end
 
  def self.create_at(dir)
    unless contains_gitfile?(dir)
      Rugged::Repository.create_at(dir)
    end
    Repo.from_dir(dir)
  end

  def self.lowest_above(dir)
    res_dir = nil
    dir.ascend { |f|
      if is_repo_dir?(f)
        res_dir = f
        break
      end
    }   
    res_dir 
  end

  def self.highest_above(dir)
    res_dir = nil
    dir.ascend { |f|
      if is_repo_dir?(f)
        res_dir = f
      end
    }  
    Repo.from_dir(res_dir)
  end

  def self.from_repo_info(repo_info)
    sub_repos = repo_info.subrepos.map(&:from_repo_info)
    Repo.new(
      repo_info.path_to.dirname,
      sub_repos,
      repo_info.is_head,
    )
  end

  def self.from_dir(dir)
    from_repo_info(RepoInfo.from_json(dir + ".repo"))
  end

#convertersz
  def to_repoinfo
    RepoInfo.new(
        path_to: @repofile,
        url: @url,
        subrepos: @subrepos,
        is_head: @is_head,
    )
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
    system("git #{args_string}")
  end

  def branch(git_str)
    output = git_command_here('branch', git_str)
    @subrepos.each { |sub|
      output << sub.branch(git_str)
    }
    output
  end

  def diff(git_str)
    diff_str = capture_pty_stdout("git #{git_str}", @location)
    @subrepos.each { |sub| diff_str << sub.diff(git_str) }
    diff_str
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
    (dir + ".git").exists?
  end

  def self.is_repo_dir?(dir)
    contains_gitfile?(dir) && (dir + ".repo").exist?
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

  def git_command_here(cmd, opt_str)
    self.class.git_command(cmd, opt_str, @location)
  end

  def self.git_command(cmd, opt_str, dir)
    capture_pty_stdout("#{cmd} #{opt_str}", dir)
  end

  def self.capture_pty_stdout(cmd, dir)
    result = ''
    PTY.spawn("cd #{dir.realpath}; #{cmd}") do |stdout, stdin, pid|
      begin
        stdout.each { |line| result += line }
      rescue Errno::EIO #Done getting output
        result
      end
    end
    result
  end

  def self.pretty_page_command_to_user(cmd, dir)
    begin
      PTY.spawn("cd #{dir.realpath}; #{cmd}") do |stdout, stdin, pid|
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
  # path_to: String = relative path to .repo file from parent repo
  # subrepos: [RepoInfo] = Array of subrepos
  # is_head: Bool = Whether or not this is a head repo (no parents)
  attr_reader :path_to, :url, :subrepos, :is_head

  def initialize(path_to:, url:, subrepos: [], is_head: true)
    @path_to = path_to
    @url = url
    @subrepos = subrepos
    @is_head = is_head
  end

  # Convert to hash, encoding subrepos as path to their repofile
  # Used for serialization to disk - so that a .repo doesn't
  # hold information about its repo's grandchildren
  def to_hash
    { "path_to" => @path_to,
      "url" => @url,
      "subrepos" => @subrepos.each(&:path_to),
      "isHead" => @is_head,
    }
  end

  def to_json
    to_hash.to_json
  end

  def write_to_disk!
    File.open(@path_to, "w") { |f| f << to_json }
  end

  def recursive_write_to_disk!
    write_to_disk!
    subrepos.each(&:recursive_write_to_disk!)
  end

  #class initializers
  def self.from_json(path)
    file = File.read(path)
    hash = JSON.parse(file)

    subrepos = hash["subrepos"].each { |path_to_sub| from_json(path_to_sub) }
    self.new(
      path_to: hash["path_to"],
      url: hash["url"],
      subrepos: subrepos,
      is_head: hash["is_head"],
    )
  end

end
