require 'filbert/db_config'
require 'filbert/log'
require 'clean_files/cleaner'

module Filbert
  class Task < Thor
    include Thor::Actions

    method_option :app, type: :string, required: true
    method_option :log, type: :string, required: false
    desc "backup", "capture and pull latest production snapshot and migrate local database"
    def backup
      say "Looking for the follower DB..."
      db_name = run!("heroku pg:info --app #{options[:app]} | grep -A 1 Followers | awk 'NR==2'").strip
      say "Found the follower: #{db_name}. Capturing..."
      backup_id = run!("heroku pgbackups:capture #{db_name} --expire --app #{options[:app]} | grep backup | awk '/--->/ { print $3}'").strip
      if backup_id != "error"
        say "Backup id: #{backup_id}"
        say "Fetching backup S3 URL"
        backup_url = run!("heroku pgbackups:url #{backup_id} --app #{options[:app]} ").strip.gsub("\"", "")
        say "Downloading #{backup_url}"
        get backup_url, file_path
        say file_path
        Log.new(:backup, db_name, options[:log]).success if File.exists?(file_path) && options[:log]
      else
        say "Error capturing #{db_name}. Run `heroku pgbackups --app #{options[:app]}` to see if there are any transfers in progress."
        exit! 1
      end
    end

    method_option :pretend, type: :boolean, required: false, default: false, aliases: '-p'
    desc "cleanup", "Remove old dumps intelligently keeping some of them"
    def cleanup
      pretend = options[:pretend]
      say "Would remove:" if pretend
      filter = File.join(backups_dir, "*.dump")
      CleanFiles::Cleaner.new(filter, pretend: pretend, verbose: pretend, threshold: 6.months.ago, monthly: true).start
      CleanFiles::Cleaner.new(filter, pretend: pretend, verbose: pretend, threshold: 3.months.ago, weekly: true).start
      CleanFiles::Cleaner.new(filter, pretend: pretend, verbose: pretend, threshold: 1.week.ago,   daily: true).start
      CleanFiles::Cleaner.new(filter, pretend: pretend, verbose: pretend, threshold: 12.hours.ago, hourly: true).start
    end

    method_option :config, type: :string, default: "config/database.yml"
    method_option :env, type: :string, default: "development"
    desc "restore", "restore the latest db dump"
    def restore
      most_recent_file = ordered_dumps.last
      check_dump_ready(most_recent_file)

      say "Restoring: #{db_config.database} <--- #{most_recent_file.path}"
      invoke :kill_connections
      ENV['PGPASSWORD'] = db_config.password
      run! "pg_restore --clean --no-acl --no-owner -U #{db_config.username} -d #{db_config.database} -w #{most_recent_file.path}"

    rescue Errno::ENOENT
      say "Could not find config file #{options[:config]}. Please pass in --config with a path to database.yml"
    ensure
      ENV['PGPASSWORD'] = nil
    end

    method_option :config, type: :string, default: "config/database.yml"
    method_option :env, type: :string, default: "development"
    desc "kill_connections", "Kills all open connections to the db"
    def kill_connections
      database = db_config.database
      user = db_config.username

      ENV['PGPASSWORD'] = db_config.password
      sql = "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();"
      run! "echo \"#{sql}\" |  psql -d #{database} -U #{user}"
      say "Killed connections to #{database} as #{user}"
    ensure
      ENV['PGPASSWORD'] = nil
    end

    private

      def run!(cmd)
        out = `#{cmd}`
        unless $?.success?
          say "Command exited with status #{$?.to_i}. Exiting.", :red
          exit! $?.exitstatus
        end
        out
      end

      def ordered_dumps
        Dir.new(backups_dir).select{ |x|
          x.end_with? '.dump'
        }.map { |filename|
          File.new(File.join(backups_dir, filename))
        }.sort_by(&:mtime)
      end

      def file_path
        @filename ||= File.join(backups_dir, "#{options[:app]}_#{Time.now.strftime("%Y-%m-%d_%H-%M-%L")}.dump")
      end

      def backups_dir
        File.join(Dir.home, '.heroku_backups')
      end

      def check_dump_ready(most_recent_file)
        if most_recent_file.nil?
          say "Didn't find any backup files in #{backups_dir}"
          exit 0
        end
      end

      def db_config
        @db_config ||= begin
          db_config = DbConfig.new(options[:config], options[:env])
          if db_config.config.nil?
            say "Could not find config for \"#{options[:env]}\" in #{options[:config]}"
            exit 0
          end
          db_config
        end
      end
  end
end
