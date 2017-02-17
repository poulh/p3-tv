require 'fileutils'
require 'json'

require 'eztv'
require 'imdb'
require 'tvdb_party'


module TVTime

    class Settings
        attr_accessor :path
        DEPRECATED_PATH = File::expand_path( "~/.tvtime" )
        DEFAULT_PATH = File::expand_path( "~/.tvtime/tvtime" )
        DEFAULTS = {
            :library_path => '~/Movies',
            :download_path => '~/Downloads',
            :delete_duplicate_downloads => false,
            :overwrite_duplicates => false,
            :allowed_types => ['.avi', '.mkv', '.mp4'],
            :subtitles => ['.srt'],
            :high_def => true,
            :verbose => false,
            :dry_run => false,
            :series => []
        }

        def self.exists?( path = DEFAULT_PATH )
            if( File::directory?( DEPRECATED_PATH ) )
                return File::exists?( path )
            else
                if( File::exists?( DEPRECATED_PATH ) )
                    puts "please move your settings file #{DEPRECATED_PATH} to #{DEFAULT_PATH}"
                    return false
                end
            end
        end

        def self.create_default!( path = DEFAULT_PATH )
            raise "a settings file already exists. please delete #{path} first" if exists?( path )

            FileUtils::mkdir_p( File::dirname( path ) )
            settings = Settings.new( path )
            DEFAULTS.each do | key, value |
                settings[ key ] = value
            end
            settings.save!
        end

        def self.set!( key, value, path = DEFAULT_PATH )
            settings = Settings.new( path )
            settings[ key ] = value
            settings.save!
        end

        def initialize( path = DEFAULT_PATH )
            @path = path
            @values = {}

            return unless File::exists?( @path )

            FileUtils::mkdir_p( File::dirname( @path ) )

            f = File::open( @path, 'r' )
            @values = JSON::parse( f.read, :symbolize_names => true )
            f.close

            self[:library_path] = [ self[:library_path], "TVTime" ].join( File::SEPARATOR ) if self[:create_tvtime_dir ]
            self[:library_path] = File::expand_path( self[:library_path ] )
            self[:download_path] = File::expand_path( self[:download_path ] )
            self[:series].uniq!

            if( self[:overwrite_duplicates] and self[:delete_duplicate_downloads] )
                raise "you cannot have 'overwrite_duplicates' and 'delete_duplicate_downloads' both set to true"
            end

        end

        def []( key )
            return @values[ key ]
        end

        def []=( key, value )
            @values[ key ] = value
        end

        def add_series!( series )
            self[:series] << series
            self[:series].uniq!
        end

        def remove_series!( series )
            self[:series].reject!{|s| s[:imdb_id] == series[:imdb_id] }
        end

        def save!
            f = File::open( @path, 'w' )
            f.puts( JSON::pretty_generate( @values ) )
            f.close
        end
    end

    class Episode
        attr_accessor :series, :season, :episode, :title, :air_date, :path
        attr_writer :type

        def type
            unless @type
                if( @path )
                    ext = File::extname( @path )
                    @type = ext unless ext.empty?
                end
            end
            return @type
        end

        def to_json(*a)
            return to_h.to_json(*a)
        end

        def to_h
            return { :series => series, :season => season, :episode => episode, :title => title, :air_date => air_date.to_s, :path => path }
        end

        def to_s
            return to_h.to_s
        end
    end

    class Series
        def initialize( path )
            @path = path
            @name = File::basename( path )
            @seasons = {}
        end
    end

    class Library

        def initialize( settings = Settings.new )
            @settings = settings
        end

        def exists?( episode )
            Dir::glob( episode_path( episode ) ).each do | path |
                return true if File::exists?( path )
            end
            return false
        end


        def format_season( episode )
            return episode.season.to_s.rjust( 2, '0' )
        end

        def format_episode( episode )
            return episode.episode.to_s.rjust( 2, '0' )
        end


        def episode_path( episode )
            formatted_title = ::TVTime::format_title( episode.series )
            return [ @settings[:library_path],
                     formatted_title,
                     "Season #{format_season( episode )}",
                     "#{formatted_title} S#{format_season( episode )}E#{format_episode( episode )}" + ( episode.type or '.*' )
                   ].join( File::SEPARATOR )
        end

        def catalog!( episode )
            cataloged_path  = episode_path( episode )
            cataloged_dir = File::dirname( cataloged_path )

            unless File::exists?( cataloged_dir )
                FileUtils::mkdir_p( cataloged_dir, { :noop => @settings[:dry_run], :verbose => @settings[:verbose] } )
            end

            if( !File::exists?( cataloged_path ) or @settings[:overwrite_duplicates] )
                FileUtils::move( episode.path, cataloged_path, { :noop => @settings[:dry_run], :verbose => @settings[:verbose], :force => true } )
            elsif( @settings[:delete_duplicate_downloads] )
                FileUtils::remove( episode.path, { :noop => @settings[:dry_run], :verbose => @settings[:verbose] } )
            else
                STDERR.puts "file exists. doing nothing: #{cataloged_path}" if @settings[:verbose]
            end
        end
    end

    class Downloads

        REGEX = [ /[sS](\d{1,2})[eE](\d{1,2})/, #s1e2, s01e02, S1E02, S01E2
                  /(\d{1,2})x(\d{1,2})/, #1x2, 01x2, 1x02, 01x02
                  /E(\d{2})/ #E02
                ]

        def initialize( settings = Settings.new )
            @settings = settings
        end


        def create_episode!( path )
            e = nil
            @settings[:series].each do | series |
                next unless( ::TVTime::path_contains_series?( path, series[:title] ) )

                REGEX.each do | regex |
                    match_data = path.match( regex )
                    if( match_data )
                        e = Episode.new
                        e.series = series[:title]
                        e.season = match_data.size == 2 ? '1' : match_data[1]
                        e.episode = match_data[ match_data.size - 1 ]
                        e.path = path
                        break
                    end
                end
                break if e
            end
            return e
        end

        def allowed_type?( path )
            return ( @settings[:allowed_types].include?( File::extname( path ) ) or @settings[:subtitles].include?( File::extname( path ) ) )
        end

        def each_file
            glob = [ @settings[:download_path], '**/*' ].join( File::SEPARATOR )
            Dir::glob( glob ).each do | path |
                yield( path )
            end
        end

        def each_allowed_file
            each_file do | path |
                next unless allowed_type?( path )
                yield( path )
            end
        end

        def each_episode
            each_allowed_file do | path |
                episode = create_episode!( path )
                yield( episode ) if episode
            end
        end
    end

    def self.format_title( title )

        rval = title
        ["'",'(',')'].each do | remove |
            rval.gsub!( remove, '')
        end

        return rval
    end

    def self.path_contains_series?( path, title )
        formatted_title = ::TVTime::format_title( title )
        if path.scan( /#{formatted_title}/i ).empty? #case insensative
            if path.scan( /#{formatted_title.gsub(' ','.')}/i ).empty? # Titles.With.Periods.Instead.Of.Spaces
                return false
            end
        end
        return true
    end

    class Search
        def initialize( settings = Settings.new )
            @settings = settings
        end

        def find_series( title )
            tvdb = TvdbParty::Search.new( nil ) #you don't need a Tvdb API key for basic search

            results = tvdb.search( title )
            results.select!{|r| r['FirstAired'] } #must have this field

            #assume the more-recent show first
            results.sort!{ | a,b |  b['FirstAired'] <=> a['FirstAired'] }
            results.collect!{ | r | { :title => r['SeriesName'], :imdb_id => r['IMDB_ID'] } }
            results.reject!{ | r | r[:imdb_id] == nil }
            return results
        end

        def each_episodes_from_imdb
            @settings[:series].each do | series |
                create_episodes_from_imdb( series ) do | episode |
                    yield( episode )
                end
            end
        end

        def create_episodes_from_imdb( series )
            imdb = Imdb::Serie.new( series[:imdb_id].gsub('tt','') )
            raise "bad imdb_id: #{series}" unless imdb
            1.upto( imdb.seasons.size ) do | season |
                imdb_season = imdb.season( season )
                1.upto( imdb.season( season ).episodes.size ) do | episode |
                    e = Episode.new
                    e.series = series[:title]
                    e.season = season
                    e.episode = episode

                    imdb_episode = imdb_season.episode( episode )
                    if( imdb_episode ) # this comes back nil sometimes
                        e.title = imdb_episode.title
                        begin
                            # sometimes the dates that come back are bad
                            e.air_date = Date::parse( imdb_episode.air_date )
                        rescue
                        end

                        yield( e ) if e.air_date

                    else
                        STDERR.puts "invalid episode: #{series} #{season} #{episode}" if @settings[:verbose]
                    end
                end
            end
        end

        def each_missing_episode( library )
            today = Date::today

            each_episode_from_imdb  do | episode |
                unless( library.exists?( episode ) )
                    if( episode.air_date <= today )
                        yield( episode )
                    end
                end
            end
        end

        def each_missing_magnet_link( library )

            eztv = {}

            each_missing_episode( library ) do | episode |
                unless eztv.has_key?( episode.series )
                    ez = EZTV::Series.new( ::TVTime::format_title( episode.series ) )
                    ez.high_def! if @settings[:high_def]
                    eztv[ episode.series ] = ez
                end

                eztv_episode = eztv[ episode.series ].episode( episode.season, episode.episode )

                if eztv_episode
                    yield( eztv_episode.magnet_link )
                else
                    STDERR.puts "could not find #{episode} on eztv" if @settings[:verbose]
                end
            end
        end
    end

    def self.add_series!( title )
        settings = Settings.new
        search = Search.new( settings )

        results = search.find_series( title )

        settings.add_series!( results[0] )
        settings.save!
    end

    def self.test_mode_enabled?
        settings = Settings.new
        return ( settings[:verbose] and settings[:dry_run] )
    end

    def self.enable_test_mode!( enable )
        Settings::set!( :dry_run, enable )
        Settings::set!( :verbose, enable )
    end


    def self.catalog_file!( path, settings = Settings.new )
        downloads = Downloads.new( settings )
        return if downloads.allowed_type?( path )
        library = Library.new( settings )
        episode = downloads.create_episode!( path )
        library.catalog!( episode ) if episode
        return nil
    end

    def self.catalog_downloads!( settings = Settings.new )
        downloads = Downloads.new( settings )
        library = Library.new( settings )

        downloads.each_episode do | episode |
            library.catalog!( episode )
        end
        return nil
    end

    def self.download_missing!( settings = Settings.new )
        search = Search.new( settings )
        library = Library.new( settings )

        search.each_missing_magnet_link( library ) do | magnet_link |
            cmd = "open #{magnet_link}"
            puts cmd if settings[:verbose]
            unless settings[:dry_run]
                system( cmd )
                sleep( 5 )
            end
        end
    end


end
