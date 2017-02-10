# TVTime

A Swiss army knife gem for managing and downloading TV shows

## Installation

    $ gem install tvtime

## Usage

Fetch a series and get all the magnet links:
```ruby
require 'tvtime'

TVTime::catalog_downloads!
TVTime::download_missing!
```


## Contributing

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
