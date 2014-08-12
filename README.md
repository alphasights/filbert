# Filbert

Filbert downloads a backup of a follower database for a given heroku application, stores it in `~/.heroku_backups`, and cleans up the backup directory (see cleanup).

## Installation

    gem install filbert

And reload your path (e.g. `rbenv rehash`). Then run

    heroku login

to get access to the app you are planning to backup.

## Usage

### Backups

Note: the backup task invokes cleanup task automatically.

    filbert backup --app your-heroku-appname

You can add it as a cron task if you want

    crontab -e

    # Then put this in there to run every 15 minutes.
    # 'man 5 crontab' for more examples
    */15 * * * * bash -lc "filbert backup --app heroku-app-name"

### Cleanup

You can invoke the cleanup task separately by running:

    filbert cleanup

Cleanup deletes backup files keeping:

* All files that are not older than 12 hours old
* One monthly copy of files older than 6 months
* One weekly copy of files older than 2 months
* One daily copy of files older than 2 days
* One hourly copy of files older than 6 hours

You can see what files would be deleted by passing in `-p`

    filbert cleanup --pretend
    # => Would delete:
    # => ~/.heroku_backups/2013-01-29.dump
    # => ~/.heroku_backups/2013-01-28.dump
    # => ~/.heroku_backups/2013-01-27.dump

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
