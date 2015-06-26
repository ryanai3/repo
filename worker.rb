class Worker
  def directory_contains_repo?(directory)
    repo_file = File.expand_path(".repo", directory)
    return File.exist?(repo_file)
  end
end