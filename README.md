# TVTime
[![Gem Version](0.0.1)
[![Code Climate](https://codeclimate.com/github/poulh/tvtime.png)](https://codeclimate.com/github/poulh/tvtime)

A Ruby scraper as a substitution for the catastrophic [EZTV](http://eztv.it/) API. It is not using the RSS feed since it doesn't work well, so it scrapes the search results.

## Installation

    $ gem install eztv

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
