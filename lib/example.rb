#!/usr/bin/ruby

require_relative 'tvtime'

#TVTime::catalog_downloads!
TVTime::each_missing_episode do | episode |
    puts episode
end
