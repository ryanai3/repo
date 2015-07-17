#!/usr/bin/env ruby
require 'thor'
require_relative './Repo.rb'
require 'pathspec'
require 'pty'

#This Class functions as the CL utility for Rgit - handles
#creating and calling Repo's in subdirectories
#and user input
class Rgit < Thor

  desc "add", "Add file contents to the index"

  def add(*args)
    set_dir_info
    if args.all? { |i| refers_to_file?(i) }
      #if add is used simply, (listing files) we can handle it ourself
      repo = Repo.highest_above(@current_dir)
      repo.stage_files(args)

    else # if args, use git (for interactive stuff too) and then repoify it
      sys_call_git(*args)

    end

    print("success")
  end

  desc "git", "Calls vanilla git with your args"

  def git(*args)
    sys_call_git(*args)
  end

  desc "init", "Create an empty Repository"

  def init
    Repo.init_at(dir)
  end

  desc "pull", "Pulls TODO"

  def pull
  end

  desc "diff", "diffs TODO"
  def diff(*args)
    # Git does something very nice with diff and pathspecs, it simply doesn't do anything for
    # the pathspecs referring to git repositories inside the current one.
    set_dir_info
    repo = Repo.highest_above(@current_dir)
    # repo.diff(*args)
    puts repo.capture_pty_stdout('git --no-pager diff')
  end



  desc "test me", "pls"
  def test_me
  end


  no_commands {
    def sys_call_git(*args)
      args_string = args.map { |i| i.to_s }.join(" ")
      system(' git ' + args_string)
    end

    def set_dir_info
      @current_dir = Dir.pwd
    end
  }
end

Rgit.start
