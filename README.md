# TVTime
[![Gem Version](https://badge.fury.io/rb/tvtime.svg)](http://badge.fury.io/rb/tvtime)

A Swiss army knife gem for managing and downloading TV shows

## Installation
    $ # we have to manually install eztv gem until i am added as owner
    $ git clone https://github.com/poulh/eztv.git
    $ cd eztv
    $ gem build eztv.gemspec
    $ sudo gem install eztv-0.0.6.gem
    $ # this gem is easy
    $ sudo gem install tvtime

## Usage

Fetch a series and get all the magnet links:
```ruby
require 'tvtime'

TVTime::Settings::create_default! unless TVTime::Settings::exists?
TVTime::add_series!( "Black Sails" )
TVTime::enable_test_mode!( true )

TVTime::catalog_downloads!
TVTime::download_missing!

```


## Contributing

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
