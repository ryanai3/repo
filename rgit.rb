#!/usr/bin/env ruby
require 'thor'
require_relative './Repo.rb'
require 'pathspec'
require 'pty'
require 'pathspec'

#This Class functions as the CL utility for Rgit - handles
#creating and calling Repo's in subdirectories
#and user input
class Rgit < Thor

  desc "add", "Add file contents to the index"
  method_option :dry_run, :aliases => "n", :type => :boolean, :default => false
  method_option :verbose, :aliases => "v", :type => :boolean, :default => false
  method_option :force, :aliases => "f", :type => :boolean, :default => false
  method_option :interactive, :aliases => "i", :type => :boolean, :default => false
  method_option :patch, :aliases => "p", :type => :boolean, :default => false
  method_option :edit, :aliases => "e", :type => :boolean, :default => false
  method_option :update, :aliases => "u", :type => :boolean, :default => false
  method_option :no_ignore_removal, :aliases => "A all", :type => :boolean, :default => false
  method_option :ignore_removal, :aliases => "no-all", :type => :boolean, :default => false
  method_option :intent_to_add, :aliases => "N", :type => :boolean, :default => false
  method_option :refresh, :type => :boolean, :default => false
  method_option :ignore_errors, :type => :boolean, :default => false
  method_option :ignore_missing, :type => :boolean, :default => false

  def add(*pathspecs)
    set_dir_info
    spec = PathSpec.new()
    spec.add(pathspecs)
    matched_files = spec.match_tree(@current_dir)
    headRepo = Repo.highest_above(@current_dir)
    headRepo.stage_files(matched_files)
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
