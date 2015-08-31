#!/usr/bin/env ruby
require "rubygems"
require 'thor'
require_relative './Repo.rb'
require 'pathspec'
require 'pty'
require 'pathname'

#This Class functions as the CL utility for Rgit - handles
#creating and calling Repo's in subdirectories
#and user input
class Rgit < Thor
  no_commands { 
    def format_options(option_hash)
      result = ""
      option_hash.each { |k, v|
        key_str = " --#{k.to_s.gsub("_","-")}"
        case v # v is truthy in all cases except: nil, false
        when [true, false].include?(v) # it's a boolean
          result << key_str
        when String
          result << key_str << "=#{v}"
        when Fixnum
          result << key_str << "=#{v}"
        when Hash
          v.each { |key, val|
            result << key_str << " #{key}=#{val}"
          }
        end 
      }
      result  
    end  
  }

  desc "add", "Add file contents to the index"
  method_option :dry_run, aliases: "n", type: :boolean, default: false
  method_option :verbose, aliases: "v", type: :boolean, default: false
  method_option :force, aliases: "f", type: :boolean, default: false
  method_option :interactive, aliases: "i", type: :boolean, default: false
  method_option :patch, aliases: "p", type: :boolean, default: false
  method_option :edit, aliases: "e", type: :boolean, default: false
  method_option :update, aliases: "u", type: :boolean, default: false
  method_option :no_ignore_removal, aliases: "A all", type: :boolean, default: false
  method_option :ignore_removal, aliases: "no-all", type: :boolean, default: false
  method_option :intent_to_add, aliases: "N", type: :boolean, default: false
  method_option :refresh, type: :boolean, default: false
  method_option :ignore_errors, type: :boolean, default: false
  method_option :ignore_missing, type: :boolean, default: false

  def add(*pathspecs)
    set_dir_info
    spec = PathSpec.new()
    spec.add(pathspecs)
    matched_files = spec.match_tree(@current_dir)
    headRepo = Repo.highest_above(@current_dir)
    headRepo.add(matched_files)
  end

  

  @init_descriptions = {
    long_desc:
      "This command creates an empty Git repository - basically a .git "\
      "directory with subdirectories for objects, refs/heads, refs/tags, "\
      "and template files. "\
      "An initial HEAD file that references the HEAD of the master branch is "\
      " also created."\
      "\n\n"\
      "If the $GIT_DIR environment variable is set then it specifies a path "\
      "to use instead of ./.git for the base of the repository."\
      "\n\n"\
      "If the object storage directory is specified via the "\
      "$GIT_OBJECT_DIRECTORY environment variable then the sha1 directories "\
      "are created underneath - otherwise the default $GIT_DIR/objects "\
      "directory is used."\
      "\n\n"\
      "Running git init in an existing repository is safe. It will not"\
      "overwrite things that are already there. The primary reason for"\
      "rerunning git init is to pick up newly added templates (or to move"\
      "the repository to another place if --separate-git-dir is given).",
    quiet:
      "\n\t"\
      "Only print error and warning messages; all other output will be suppressed."\
      "\n\n",
    bare:
      "\n\t"\
      "Create a bare repository. If GIT_DIR environment is not set, "\
      "it is set to the current working directory."\
      "\n\n",
    separate_git_dir:
      "\n\t"\
      "Instead of initializing the repository as a directory to either "\
      "$GIT_DIR or ./.git/, create a text file there containing the path "\
      "to the actual "\
      "\n\t"\
      "repository. This file acts as filesystem-agnostic Git "\
      "symbolic link to the repository."\
      "\n\n\t"\
      "If this is reinitialization, "\
      "the repository will be moved to the specified path."\
      "\n\n",
    shared:
      "\n\t"\
      "Specify that the Git repository is to be shared amongst several users."\
      "This allows users belonging to the same group to push into that repository."\
      "\n\t"\
      "When specified, the config variable \"core.sharedRepository\" is set so that"\
      "files and directories under $GIT_DIR are created with the requested permissions."\
      "\n\t"\
      "When not specified, Git will use permissions reported by umask(2)."\
      "\n\n",
    template:
      "\n\t"\
      "Specify the directory from which templates will be used."\
      "(See the \"TEMPLATE DIRECTORY\" section below.)"\
      "\n\n",
  }

  desc "init", "Create an empty Rgit repository or reinitialize an existing one"
  long_desc @init_descriptions[:long_desc]
  method_option :quiet,
    { aliases: "q",
      type: :boolean,
      default: false,
      desc: @init_descriptions[:quiet]
    }
  method_option :bare,
    { type: :boolean,
      default: false,
      desc: @init_descriptions[:bare]
    }
  method_option :template,
    { type: :string,
      desc: @init_descriptions[:template]
    }
  method_option :separate_git_dir,
    { type: :string,
      desc: @init_descriptions[:separate_git_dir]
    }
  method_option :shared,
    { type: :string,
      enum: ["false", "true", "umask", "group", "all", "world", "everybody"],
      desc: @init_descriptions[:shared]
    }

  def init(*arg)
    set_dir_info
    # If no dir is specified, use current dir, otherwise absolute path of specified dir
    directory = arg.empty? ? @current_dir : Pathname.new(arg[0]).realpath
    # thor hands us a frozen hash, ruby-git messes with it, so we hand it a shallow copy of the hash
    Repo.init(directory, options.dup)
    puts("Initialized empty rGit repository in #{directory}") unless options[:quiet]
  end
 

  @clone_descriptions = {
    local:
      "When the repository to clone from is on a local machine, this flag
       bypasses the normal \"Git aware\" transport mechanism and clones the
       repository by making a copy of HEAD and everything under objects and
       refs directories. The files under .git/objects/ directory are hardlinked
       to save space when possible.

       If the repository is specified as a local path (e.g., /path/to/repo),
       this is the default, and --local is essentially a no-op. If the repository
       is specified as a URL, then this flag is ignored (and we never use the local
       optimizations). Specifying --no-local will override the default when
       /path/to/repo is given, using the regular Git transport instead.",
    bare:
      ""



  }

  desc "clone", "Clone a repository into a new directory"
  long_desc @clone_descriptions[:long_desc]

  method_option :local,
    { aliases: "l",
      type: :boolean,
      desc: @clone_descriptions[:local],
    }
  method_option :no_hardlinks,
    { type: :boolean, 
      desc: @clone_descriptions[:no_hardlinks],
    }
  method_option :shared,
    { type: :boolean,
      desc: @clone_descriptions[:shared],
    }
  method_option :reference,
    { type: :string,
      desc: @clone_descriptions[:reference],
    }
  method_option :dissociate,
    { type: :boolean,
      desc: @clone_descriptions[:dissociate],
    }
  method_option :quiet,
    { aliases: "q",
      type: :boolean,
      desc: @clone_descriptions[:quiet],
    }
  method_option :verbose,
    { aliases: "v",
      type: :boolean,
      desc: @clone_descriptions[:verbose],
    }
  method_option :progress,
    { type: :boolean,
      desc: @clone_descriptions[:progress],
    }
  method_option :no_checkout,
    { aliases: "n",
      type: :boolean,
      desc: @clone_descriptions[:no_checkout],
    }
  method_option :bare,
    { type: :boolean,
      desc: @clone_descriptions[:bare],
    }
  method_option :mirror,
    { type: :boolean,
      desc: @clone_descriptions[:mirror],
    }
  method_option :branch,
    { aliases: "b",
      type: :string,
      desc: @clone_descriptions[:branch],
    }
  method_option :upload_pack,
    { aliases: "u",
      type: :boolean,
      desc: @clone_descriptions[:upload_pack],
    }
  method_option :template,
    { type: :string,
      desc: @clone_descriptions[:template],
    }
  method_option :config,
    { aliases: "c",
      type: :hash,
      desc: @clone_descriptions[:config],
    }
  method_option :depth,
    { type: :numeric,
      desc: @clone_descriptions[:depth],
    }
  method_option :single_branch,
    { type: :boolean,
      desc: @clone_descriptions[:single_branch],
    }
  method_option :separate_git_dir,
    { type: :string,
      desc: @clone_descriptions[:separate_git_dir],
    }
  
  def clone(repository, *directory)
    directory = directory.empty? ? @current_dir : Pathname.new(directory[0]).realpath 
    git_str = format_options(options)
    Repo.clone(repository, directory, git_str)
  end

  desc "git", "Calls vanilla git with your args"

  def git(*args)
    sys_call_git(*args)
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
    repo.diff(*args)    
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
      @current_dir = Pathname.pwd
    end
  }
end

Rgit.start
