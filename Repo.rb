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
  def add(*args)
    set_dir_info
    repofile2gitfile
    if args.all?{|i| refers_to_file?(i)}
      #if add is used simply, (listing files) we can handle it ourself


    else # if args, use git (for interactive stuff too) and then repoify it
      system_call_git(*args)

    end


    print("success")
  end

  desc "git", "turns .repo unto .git then calls git"
  def git(*args)
    safe_repofile2gitfile
    system_call_git(*args)
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
    def system_call_git(*args)
      args_string = args.map{ |i| i.to_s}.join(" ")
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
  }


end

Repo.start

