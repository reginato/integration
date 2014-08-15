require 'find'

namespace :integration do
  def project_name
    File.expand_path(Rails.root).split("/").last
  end

  def p80(message)
    puts "-"*80
    puts message if message
    yield if block_given?
  end

  def remove_old_backups(backup_dir)
    backups_to_keep = ENV['NUMBER_OF_BACKUPS_TO_KEEP'] || 30
    backups = []
    Find.find(backup_dir) { |file_name| backups << file_name if !File.directory?(file_name) && file_name =~ /.*\.tar.gz$/ }
    backups.sort!
    (backups - backups.last(backups_to_keep - 1)).each do |file_name|
      puts "Removing #{file_name}..."
      FileUtils.rm(file_name)
    end
  end

  namespace :backup do
    desc 'Creates a backup of the project in the local disk.'
    task :local do
      backup_dir = '../backups/backup-' + project_name
      sh "mkdir -p #{backup_dir}" if !FileTest.exists?(backup_dir)
      remove_old_backups(backup_dir)
      sh "tar cfz #{backup_dir}/#{project_name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}.tar.gz ."
    end
  end

  namespace :git do
    desc 'Check if project can be committed to the repository.'
    task :status_check do
      result = `git status`
      if result.include?('Untracked files:') || result.include?('unmerged:') || result.include?('modified:')
        puts result
        exit
      end
    end

    desc 'Update files from repository.'
    task :pull do
      sh "git pull --rebase"
    end

    desc 'Push project.'
    task :push do
      sh "git push"
    end
  end

  task :start => ["git:status_check", "log:clear", "tmp:clear", "backup:local"] do
    ENV['COVERAGE'] = 'on'
  end
  task :finish => [""]

  desc 'Check code coverage'
  task :coverage_verify do
    if RUBY_VERSION =~ /1.8/
    sh "ruby #{File.expand_path(File.dirname(__FILE__) + '/../../test/coverage_test.rb')}"
    else
      raise "You should update your spec/spec_helper.rb and add:\nIntegration.with_full_coverage!\nThis will require SimpleCov and start it for you. You can safely remove this task afterwards."
    end
  end

  desc 'Run bundle install'
  task :bundle_install do
    sh 'bundle install'
  end

end

desc 'Integrate new code to repository'
task :integrate do
  if !defined?(INTEGRATION_TASKS)
    p80 %{
You should define INTEGRATION_TASKS constant. We recommend that you define it on lib/tasks/integration.rake file. The file doesn't exists. You should create it in your project.

You'll probably want to add coverage/ to your .gitignore file.

A sample content look like this:

INTEGRATION_TASKS = %w(
  integration:start
  integration:bundle_install
  db:migrate
  spec
  integration:coverage_verify
  jasmine:ci
  integration:finish
)

}
    exit
  end

  INTEGRATION_TASKS.each do |subtask|
    p80("Executing #{subtask}...") do
      RAILS_ENV = ENV['RAILS_ENV'] || 'development'
      Rake::Task[subtask].invoke
    end
  end
end
