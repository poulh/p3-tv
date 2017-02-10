require 'json'
require 'eztv'

module TVTime

    class Settings
        DEFAULT_PATH = File::expand_path( "~/.tvtime" )
        def initialize( path = DEFAULT_PATH )
            @values = JSON::parse( File::open( path, 'r' ).read )
            self[:library_path] = [ self[:library_path], "TVTime" ].join( File::SEPARATOR ) if self[:create_tvtime_dir ]
            self[:library_path] = File::expand_path( self[:library_path ] )
            self[:download_path] = File::expand_path( self[:download_path ] )
            self[:series].uniq!
        end

        def []( key )
            return @values[ key.to_s ]
        end

        def []=( key, value )
            @values[ key.to_s ] = value
        end
    end

    class Episode
        attr_accessor :series, :season, :episode, :path
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

            unless( @settings[:allowed_types].include?( episode.type ) or @settings[:subtitles].include?( episode.type ) )
                raise "file type not allowed. add type to #{@settings.path} 'allowed_types'"
            end

            cataloged_path  = episode_path( episode )
            cataloged_dir = File::dirname( cataloged_path )
            
            unless File::exists?( cataloged_dir )
                FileUtils::mkdir_p( cataloged_dir, { :noop => @settings[:noop], :verbose => @settings[:verbose] } )
            end

            if( File::exists?( cataloged_path ) )
                puts "file exists: #{cataloged_path}" if @settings[:verbose]
            else
                FileUtils::move( episode.path, cataloged_path, { :noop => @settings[:noop], :verbose => @settings[:verbose] } )
            end
        end
    end

    class Downloads
        def initialize( settings = Settings.new )
            @settings = settings
        end

        
        def create_episode!( series, path )
            raise "path #{path} does not contain series name #{series}" unless path.index( series )

            e = nil
            @settings[:download_regex].each do | regex |
                match_data = path.match( /#{regex}/)
                if( match_data )
                    e = Episode.new
                    e.series = series
                    e.season = match_data[1]
                    e.episode = match_data[2]
                    e.path = path
                    
                    raise "cannot determine file type" unless e.type
                    break
                end
            end
            
            raise "could not create episode #{path}" unless e
            return e
        end
        
        def each_episode
            glob = [ @settings[:download_path], '**/*' ].join( File::SEPARATOR )
            Dir::glob( glob ).each do | path |
                unless File::directory?( path )
                    @settings[:series].each do | series |
                        begin
                            episode = create_episode!( series, path )
                            yield( episode )
                            break
                        rescue => e
                            #puts e
                        end
                    end
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
                #puts e
            end
        end
        return nil
    end

    def self.each_missing_magnet_link
        settings = Settings.new
        library = Library.new( settings )
        settings[:series].each do | series |
            begin
                eztv = EZTV::Series.new( series )
                eztv.high_def!
                eztv.episodes.each do | eztv_episode |
                    e = Episode.new
                    e.series = series
                    e.season = eztv_episode.season
                    e.episode = eztv_episode.episode_number
                    unless( library.exists?( e ) )
                        yield( eztv_episode.magnet_link )
                    end
                end
            end
        end
    end

    def self.download_missing!
        each_missing_magnet_link do | magnet_link |
            system( "open #{magnet_link}" )
            sleep( 5 )
        end
    end
end


