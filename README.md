# P3TV
[![Gem Version](https://badge.fury.io/rb/p3-tv.svg)](http://badge.fury.io/rb/p3-tv)

Organize and rename your TV Shows. Automatically find links to missing shows. Includes Command-Line Utility

## Installation
    $ sudo gem install p3-tv

## Usage

Run 'p3tv' at the command prompt and choose from the menu

    $ p3tv
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
require 'p3-tv'

P3::TV::Settings::create_default! unless P3::TV::Settings::exists?
P3::TV::add_series!( "Black Sails" )
P3::TV::enable_test_mode!( true )

P3::TV::catalog_downloads!
P3::TV::download_missing!

```


## Contributing

1. Fork it.
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
