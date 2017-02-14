# TVTime
[![Gem Version](https://badge.fury.io/rb/tvtime.svg)](http://badge.fury.io/rb/tvtime)

Organize and rename your TV Shows. Automatically find links to missing shows. Includes Command-Line Utility

## Installation
    $ sudo gem install tvtime

## Usage

Run 'tvtime' at the command prompt and choose from the menu

    $ tvtime
    1. Search for TV Series
    2. List TV Series
    3. Download Missing Episodes
    4. Catalog Downloads
    5. Manage Directories
    6. Test Mode
    7. quit
    What do you want to do?


## Development Usage

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
