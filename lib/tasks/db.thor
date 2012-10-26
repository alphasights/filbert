require 'tmpdir'
class Db < Thor
  include Thor::Actions
  class_option :app, type: :string

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
    run! "wget -O #{backup_url} #{file_path}"
    say file_path
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

    def file_path
      @filename ||= File.join("/tmp", "pto-#{Time.now.strftime("%Y_%m_%d-%H:%M:%L")}.dump")
    end
end