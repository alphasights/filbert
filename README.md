# Filbert

Filbert downloads a backup of a follower database for a given heroku application and stores it in `~/.heroku_backups`

## Installation

    gem install filbert

And reload your path (e.g. `rbenv rehash`). Then run

    heroku login

to get access to the app you are planning to backup.

## Usage

    filbert backup --app your-heroku-appname

You can add it as a cron task if you want

    crontab -e

    # Then put this in there to run every 15 minutes.
    # 'man 5 crontab' for more examples
    */15 * * * * bash -lc "filbert backup --app heroku-app-name"

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
