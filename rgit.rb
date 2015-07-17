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

  def add(*pathspecs)
    set_dir_info

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

  desc "bind", "binds a set of commits together into one commit"
  def bind
    #TODO
  end

  desc "unbind", "unbinds a set of commits"
  def unbind

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
