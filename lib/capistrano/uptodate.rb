Capistrano::Configuration.instance(true).load do
  namespace :uptodate do
    desc "Automatically synchronize current repository"
    task :default do
      next if fetch(:uptodate_skip, false)
      case scm
      when :git
        top.uptodate.git
      else
        abort("SCM #{scm} is not supported by capistrano/uptodate")
      end
    end

    task :git do
      scm = fetch(:uptodate_scm, :git)
      scm_binary = fetch(:uptodate_scm_binary, 'git')
      remote_ref = fetch(:uptodate_remote_ref, 'origin/master')
      time = fetch(:uptodate_time, 300)
      behavior = fetch(:uptodate_behaviour, fetch(:uptodate_behavior, 'confirm'))
      git_dir = fetch(:uptodate_local_repository, `#{scm_binary} rev-parse --git-dir`.strip)

      # skip if no git dir detected
      next if git_dir.empty?

      # fetch remote references
      fetch_file = File.join(git_dir, "FETCH_HEAD")
      unless File.exist?(fetch_file) && Time.now - File.mtime(fetch_file) < time
        Capistrano::CLI.ui.say "Fetching remote git repo..."
        system("#{scm_binary} fetch")
      end

      # compare local tree and remote ref
      # NB: (git `diff --quiet` has a bug where it show 0-exit the first time
      # used in clean environments like a Docker container)
      next if system("#{scm_binary} diff --exit-code #{remote_ref} > /dev/null")

      # otherwise, they're different
      remote_ref_parsed = `#{scm_binary} rev-parse --symbolic-full-name #{remote_ref}`.chomp

      Capistrano::CLI.ui.say "Local git tree is not synchronized with #{remote_ref_parsed}"

      case behavior
      when 'confirm'
        Capistrano::CLI.ui.ask("Continue anyway? (y/N)") == 'y' or abort
      when 'ignore'
        next
      else
        abort
      end
    end
  end

  on :load, 'uptodate'
end
