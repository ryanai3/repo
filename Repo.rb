#!/usr/bin/env ruby
require 'rugged'
require 'thor'
require_relative './worker.rb'

class Repo < Thor

  no_commands{
    def set_dir_info
      @initial_dir = Dir.pwd
      @current_dir = @initial_dir
      @gitfile = File.expand_path(".git", @current_dir)
    end
  }

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

  def stage_files(files)
    #filter files - ones in current dir added to index, rest handed off to subrepos
    files_in_current_dir = files.select{ |file| File.dirname(file) == @current_dir}
    files_to_handoff = files - files_in_current_dir #set difference
    #getindex
    cur_index = Rugged::Index.new(@current_dir)
    #stage files in current directory
    files_in_current_dir.each{ |file| cur_index << File.path(file)}
    cur_index.write #make sure to save it
    files_to_handoff.group_by{ |file| File.dirname(file)}.each{ |dir, files| stage_files_in(dir, files)}
  end
  #
  def stage_files_in(dir, files)
    #if dir contains .repo, create a Repo on there and call stage on it
    stage_dir = dir
    #Demorgan's: not(.repo_exists) and not(stage_dir==@current_dir) <==> not (.repo_exists or stage_dir==@current dir)
    while not (File.exist?(File.expand_path(".git", stage_dir)) or stage_dir == @current_dir)
      stage_dir = File.dirname(stage_dir)
    end
    #stage_dir is now the dir we want to stage the files into!

    cur_index = Rugged::index.new(stage_dir)
    files.each{ |file|  cur_index << File.path(file)}
    cur_index.write
    #else, stage them all yourself.
  end

  desc "git", "Calls vanilla git with your args"
  def git(*args)
    system_call_git(*args)
  end

  desc "init", "Create an empty Repository"
  def init
    set_dir_info
    unless File.exist?(@repofile)
      repository = Rugged::Repository.init_at(@current_dir)
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

