#!/usr/bin/env/ ruby
require 'thor'
require_relative './Repo.rb'

#This Class functions as the CL utility for Rgit - handles
#creating and calling Repo's in subdirectories
#and user input
class Rgit < Thor

  def set_dir_info
    @current_dir = Dir.pwd
  end

  desc "add", "Add file contents to the index"
  def add(*args)
    set_dir_info
    if args.all?{|i| refers_to_file?(i)}
      #if add is used simply, (listing files) we can handle it ourself
      stage_files(args)


    else # if args, use git (for interactive stuff too) and then repoify it
      system_call_git(*args)

    end

    print("success")
  end
  
  desc "git", "Calls vanilla git with your args"
  def git(*args)
    system_call_git(*args)
  end

  desc "init", "Create an empty Repository"
  def init
    Repo.init_at(dir)
  end

  def system_call_git(*args)
    args_string = args.map { |i| i.to_s }.join(" ")
    system(' git ' + args_string)
  end



end

Rgit.start
