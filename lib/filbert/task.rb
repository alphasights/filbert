module Filbert
  class Task < Thor
    include Thor::Actions
    class_option :app, type: :string, required: true

    method_options :real_emails => false
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

    desc "cleanup", "remove backup files older than 24 hours"
    def cleanup
      old_files.each do |file|
        say "Deleting old #{File.basename(file.path)}"
        File.delete file.path
      end
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
        Dir.new(backups_dir).select{ |x|
          x.end_with? '.dump'
        }.map { |filename|
          file = File.new(File.join(backups_dir, filename))
        }.select{ |file|
          file.mtime < hurdle
        }
      end

      def file_path
        @filename ||= File.join(backups_dir, "pto_#{Time.now.strftime("%Y-%m-%d_%H-%M-%L")}.dump")
      end

      def backups_dir
        File.join(Dir.home, '.heroku_backups')
      end
  end
end