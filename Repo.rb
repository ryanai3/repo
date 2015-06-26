#!/usr/bin/env ruby
require 'rugged'
require 'thor'
require_relative './worker.rb'

class Repo < Thor

  no_commands{
    def set_dir_info
      @initial_dir = Dir.pwd
      @current_dir = @initial_dir
      @repofile = File.expand_path(".repo", @current_dir)
      @gitfile = File.expand_path(".git", @current_dir)
    end
  }

  desc "add", "Add file contents to the index"
  def add

    return Worker.directory_contains_repo?(current_dir)
  end

  desc "git", "turns .repo unto .git then calls git"
  def git(*args)
    safe_repofile2gitfile

    args_string = args.map{ |i| i.to_s}.join(" ")
    system('git ' + args_string)

    safe_gitfile2repofile
  end

  desc "init", "Create an empty Repository"
  def init
    set_dir_info
    unless File.exist?(@repofile)
      repository = Rugged::Repository.init_at(@current_dir)
      gitfile2repofile
    end
  end
  
  no_commands{
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
  }


end

Repo.start

