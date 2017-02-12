#!/usr/bin/ruby

require_relative 'tvtime'

TVTime::Settings::create_default! unless TVTime::Settings::exists?
TVTime::add_series!( "Black Sails" )
TVTime::enable_test_mode!( true )

TVTime::catalog_downloads!
TVTime::download_missing!
