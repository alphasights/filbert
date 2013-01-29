require 'filbert/db_config'

module Filbert
  class Task < Thor
    include Thor::Actions

    method_option :app, type: :string, required: true
    desc "backup", "capture and pull latest production snapshot and migrate local database"
    def backup
      say "Looking for the follower DB..."
      db_name = run!("heroku pg:info --app #{options[:app]} | grep Followers | awk '/:(.)*/ { print $2 }'").strip
      say "Found the follower: #{db_name}. Capturing..."
      backup_id = run!("heroku pgbackups:capture #{db_name} --expire --app #{options[:app]} | grep backup | awk '/--->/ { print $3}'").strip
      say "Backup id: #{backup_id}"
      say "Fetching backup S3 URL"
      backup_url = run!("heroku pgbackups:url #{backup_id} --app #{options[:app]} ").strip.gsub("\"", "")
      say "Downloading #{backup_url}"
      get backup_url, file_path
      say file_path
      invoke :cleanup
    end

    desc "cleanup", "remove backup files older than 12 hours"
    def cleanup
      old_files.each do |file|
        say "Deleting old #{File.basename(file.path)}"
        File.delete file.path
      end
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
      sql = "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE procpid <> pg_backend_pid();"
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

      def old_files
        hurdle = Time.now - 60*60*12
        ordered_dumps.select{ |file|
          file.mtime < hurdle
        }
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