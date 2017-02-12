require 'json'
require 'eztv'
require 'imdb'

module TVTime

    class Settings
        attr_accessor :path
        DEFAULT_PATH = File::expand_path( "~/.tvtime" )
        def initialize( path = DEFAULT_PATH )
            @path = path
            @values = JSON::parse( File::open( path, 'r' ).read )
            self[:library_path] = [ self[:library_path], "TVTime" ].join( File::SEPARATOR ) if self[:create_tvtime_dir ]
            self[:library_path] = File::expand_path( self[:library_path ] )
            self[:download_path] = File::expand_path( self[:download_path ] )
            self[:series].uniq!

            if( self[:overwrite_duplicates] and self[:delete_duplicate_downloads] )
                raise "you cannot have 'overwrite_duplicates' and 'delete_duplicate_downloads' both set to true"
            end
        end

        def []( key )
            return @values[ key.to_s ]
        end

        def []=( key, value )
            @values[ key.to_s ] = value
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

        def to_s
            return { :series => series, :season => season, :episode => episode, :title => title, :air_date => air_date.to_s, :path => path }.to_s
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

        def episode_name( episode )
            #moves titles that begin with 'The' to the end
            match = /^The (.*)/.match( episode.series )
            if( match )
                return "#{match[1]}, The"
            end
            return episode.series
        end

        def format_season( episode )
            return episode.season.to_s.rjust( 2, '0' )
        end

        def format_episode( episode )
            return episode.episode.to_s.rjust( 2, '0' )
        end


        def episode_path( episode )
            formatted_name = episode_name( episode )
            return [ @settings[:library_path],
                     formatted_name,
                     "Season #{format_season( episode )}",
                     "#{formatted_name} S#{format_season( episode )}E#{format_episode( episode )}" + ( episode.type or '.*' )
                   ].join( File::SEPARATOR )
        end

        def catalog!( episode )
            raise "episode path required to catalog" unless episode.path
            raise "cannot determine file type" unless episode.type

            cataloged_path  = episode_path( episode )
            cataloged_dir = File::dirname( cataloged_path )

            unless File::exists?( cataloged_dir )
                FileUtils::mkdir_p( cataloged_dir, { :noop => @settings[:noop], :verbose => @settings[:verbose] } )
            end

            if( !File::exists?( cataloged_path ) or @settings[:overwrite_duplicates] )
                FileUtils::move( episode.path, cataloged_path, { :noop => @settings[:noop], :verbose => @settings[:verbose], :force => true } )
            elsif( @settings[:delete_duplicate_downloads] )
                FileUtils::remove( episode.path, { :noop => @settings[:noop], :verbose => @settings[:verbose] } )
            else
                puts "file exists. doing nothing: #{cataloged_path}" if @settings[:verbose]
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
            return nil unless( @settings[:allowed_types].include?( File::extname( path ) ) or @settings[:subtitles].include?( File::extname( path ) ) )

            e = nil
            @settings[:series].each do | series |
                next unless( ::TVTime::path_contains_series?( path, series['title'] ) )

                REGEX.each do | regex |
                    match_data = path.match( regex )
                    if( match_data )
                        e = Episode.new
                        e.series = series
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

        def each_episode
            glob = [ @settings[:download_path], '**/*' ].join( File::SEPARATOR )
            Dir::glob( glob ).each do | path |
                unless File::directory?( path )
                    episode = create_episode!( path )
                    yield( episode ) if episode
                end
            end
        end
    end

    def self.path_contains_series?( path, title )
        if path.scan( /#{title}/i ).empty? #case insensative
            if path.scan( /#{series.gsub(' ','.')}/i ).empty? # Titles.With.Periods.Instead.Of.Spaces
                return false
            end
        end
        return true
    end

    class Search
        def initialize( settings = Settings.new )
            @settings = settings
        end

        def each_episode_from_imdb

            @settings[:series].each do | series |
                imdb = Imdb::Serie.new( series['imdb_id'].gsub('tt','') )
                raise "bad imdb_id: #{series}" unless imdb
                1.upto( imdb.seasons.size ) do | season |
                    1.upto( imdb.season( season ).episodes.size ) do | episode |
                        e = Episode.new
                        e.series = series['title']
                        e.season = season
                        e.episode = episode

                        imdb_episode = imdb.season( season ).episode( episode )
                        if( imdb_episode ) # this comes back nil sometimes
                            e.title = imdb_episode.title
                            begin
                                # sometimes the dates that come back are bad
                                e.air_date = Date::parse( imdb_episode.air_date )
                        rescue
                            end

                            yield( e )

                        else
                            puts "invalid episode: #{series} #{season} #{episode}" if settings[:verbose]
                        end
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
                puts episode
                unless eztv.has_key?( episode.series )
                    puts "eztv searching for #{episode.series}"
                    ez = EZTV::Series.new( episode.series )
                    ez.high_def!
                    eztv[ episode.series ] = ez
                end

                eztv_episode = eztv[ episode.series ].episode( episode.season, episode.episode )

                if eztv_episode
                    yield( eztv_episode.magnet_link )
                else
                    puts "could not find #{episode} on eztv" if @settings[:verbose]
                end
            end
        end
    end

    def self.catalog_downloads!
        settings = Settings.new
        library = Library.new( settings )
        downloads = Downloads.new( settings )

        downloads.each_episode do | episode |
            begin
                library.catalog!( episode )
            rescue => e
                #  puts e
            end
        end
        return nil
    end




    def self.download_missing!
        settings = Settings.new
        search = Search.new( settings )
        library = Library.new( settings )

        search.each_missing_magnet_link( library ) do | magnet_link |
            cmd = "open #{magnet_link}"
            puts cmd if settings[:verbose]
            unless settings[:noop]
                system( cmd )
                sleep( 5 )
            end
        end
    end
end
