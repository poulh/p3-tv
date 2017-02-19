require 'fileutils'
require 'json'

require 'eztv'
require 'tvdb_party'
require 'transmission_api'


# module TvdbParty
#     class Series
#         def to_h
#             hash = {}
#             self.instance_variables.each do | var |
#                 #turn episode object into hash
#                 v = self.instance_variable_get( var )
#                 hash[ var.to_s.gsub('@','').to_sym ] = v
#             end
#             hash.delete(:client)
#             return hash
#         end

#     end

#     class Episode

#     end
# end

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
            self[:series] << series.to_h
            self[:series].uniq!
        end

        def remove_series!( seriesid )
            self[:series].reject!{|s| s[:id] == seriesid }
        end

        def save!
            f = File::open( @path, 'w' )
            f.puts( JSON::pretty_generate( @values ) )
            f.close
        end
    end

    class EpisodeFile
        attr_accessor :series, :season, :episode, :title, :air_date, :path, :status, :percent_done
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
            return { :series => series,
                     :season => season,
                     :episode => episode,
                     :title => title,
                     :air_date => air_date.to_s,
                     :path => path,
                     :status => status,
                     :percent_done => percent_done
            }
        end

        def <=>( other )
            if( self.series == other.series )
                if( self.season == other.season )
                    return self.episode <=> other.episode
                else
                    return self.season <=> other.season
                end
            else
                return self.series <=> other.series
            end
        end

        def to_s
            return to_h.to_s
        end
    end

    class Library

        def initialize( settings = Settings.new )
            @settings = settings
        end

        def exists?( episode )
            Dir::glob( episode_glob( episode ) ).each do | path |
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


        def episode_glob( episode )
            formatted_title = ::TVTime::format_title( episode.series )
            return [ @settings[:library_path],
                     formatted_title,
                     "Season #{format_season( episode )}",
                     "#{formatted_title} S#{format_season( episode )}E#{format_episode( episode )}" + ( episode.type or '.*' )
                   ].join( File::SEPARATOR )
        end

        def episode_path( episode )
            glob = episode_glob( episode )
            if( episode.type )
                return glob # this will NOT end in .*
            else
                Dir::glob( glob ).each do | path |
                    return path
                end
            end
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
                  /(\d{1,2})x(\d{1,2})/ #1x2, 01x2, 1x02, 01x02
                ]

        def initialize( settings = Settings.new )
            @settings = settings
            @transmission = nil
            @paths = nil
            @torrents = nil
        end

        def path_match( path )
            @settings[:series].each do | series |
                next unless( ::TVTime::path_contains_series?( path, series[:name] ) )
                REGEX.each do | regex |
                    match_data = path.match( regex )
                    if( match_data )
                        yield( series, match_data )
                        return
                    end
                end
            end
        end

        def create_episode!( path )
            e = nil
            path_match( path ) do | series, match_data |
                e = EpisodeFile.new
                e.series = series[:name]
                e.season = match_data[1].to_i
                e.episode = match_data[ 2 ].to_i
                e.path = path
            end
            return e
        end

        def allowed_type?( path )
            return ( @settings[:allowed_types].include?( File::extname( path ) ) or @settings[:subtitles].include?( File::extname( path ) ) )
        end

        def paths
            return @paths if @paths
            glob = [ @settings[:download_path], '**/*' ].join( File::SEPARATOR )
            @paths = Dir::glob( glob )
            @paths = @paths.select{|p| allowed_type?( p ) }
            return @paths
        end

        def torrents
            return @torrents if @torrents
            @transmission = TransmissionApi::Client.new(@settings[:transmission]) unless @transmission
            @torrents = @transmission.all
            return @torrents
        end

        def get_path_if_exists( episode_file )
            episode_files = paths().collect{|p| create_episode!( p ) }
            episode_files.select!{|ef| ef }
            episode_files.each do | dn_ep | #download_episode_file
                if( 0 == ( episode_file <=> dn_ep ) )
                    return dn_ep.path
                end
            end
            return nil
        end

        def get_torrent_if_exists( episode_file )
            torrents().each do | torrent |
                name = torrent['name']
                torrent_episode = create_episode!( name )
                if( torrent_episode )
                    if( 0 == ( episode_file <=> torrent_episode ) )
                        return torrent
                    end
                end
            end
            return nil
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
            @tvdb = TvdbParty::Search.new( @settings[:tvdb_api_key] )
            @eztv = {}
        end

        def find_series( title )
            results = @tvdb.search( title )
            results.select!{|r| r['FirstAired'] } #must have this field

            #assume the more-recent show first
            results.sort!{ | a,b |  b['FirstAired'] <=> a['FirstAired'] }
            results = results.collect{|r| find_series_by_id( r['seriesid'] ) }
            return results
        end

        def find_series_by_id( seriesid )
            return @tvdb.get_series_by_id( seriesid )
        end

        def find_episodes_by_seriesid( seriesid )
            series = find_series_by_id( seriesid )
            series.episodes.each do | episode |
                yield( episode ) if episode.season_number.to_i > 0
            end
        end

        def each_episode
            @settings[:series].each do | series_hash |
                find_episodes_by_seriesid( series_hash[:id] ) do | episode |
                    yield( episode )
                end
            end
        end


        def each_series_episode_file_status( seriesid, downloads, library )
            today = Date::today
            find_episodes_by_seriesid( seriesid ) do | episode |
                ep_file = ::TVTime::EpisodeFile.new
                ep_file.series = episode.series.name
                ep_file.season = episode.season_number.to_i
                ep_file.episode = episode.number.to_i
                ep_file.title = episode.name
                ep_file.air_date = episode.air_date

                if( ( ep_file.air_date == nil ) or ( ep_file.air_date > today ) )
                    ep_file.percent_done = 0
                    ep_file.status = :upcoming
                    ep_file.path = ''
                elsif( library.exists?( ep_file ) )
                    ep_file.percent_done = 1
                    ep_file.status = :cataloged
                    ep_file.path = library.episode_path( ep_file )
                elsif( download_path = downloads.get_path_if_exists( ep_file ) )
                    ep_file.percent_done = 1
                    ep_file.status = :downloaded
                    ep_file.path = download_path
                elsif( torrent = downloads.get_torrent_if_exists( ep_file ) )
                    ep_file.percent_done = torrent['percentDone']
                    ep_file.status = :downloading
                    ep_file.path = ''
                elsif( magnet_link = get_magnet_link_if_exists( ep_file ) )
                    ep_file.percent_done = 0
                    ep_file.status = :available
                    ep_file.path = magnet_link
                else
                    ep_file.percent_done = 0
                    ep_file.status = :missing
                    ep_file.path = ''
                end
                yield( ep_file )
            end
        end

        def eztv( series_name )
            unless( @eztv.has_key?( series_name ) )
                ez = EZTV::Series.new( ::TVTime::format_title( series_name ) )
                ez.high_def! if @settings[:high_def]
                @eztv[ series_name ] = ez
            end
            return @eztv[ series_name ]
        end

        def get_magnet_link_if_exists( episode_file )
            ez = eztv( episode_file.series )
            eztv_episode = ez.episode( episode_file.season, episode_file.episode )
            return eztv_episode.magnet_link if eztv_episode
            return nil
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

    def self.catalog_downloads_series!( seriesid, settings = Settings.new )
        search = Search.new( settings )
        library = Library.new( settings )
        downloads = Downloads.new( settings )

        search.each_series_episode_file_status( seriesid, downloads, library ) do | episode_file |
            if( episode_file.status == :downloaded )
                library.catalog!( episode_file )
            end
        end
    end


    def self.catalog_downloads!( settings = Settings.new )
        downloads = Downloads.new( settings )
        library = Library.new( settings )
        episode_files = downloads.paths.collect{|p| downloads.create_episode!( p ) }
        episode_files.select!{|ef| ef }
        episode_files.each do | episode_file |
            library.catalog!( episode_file )
        end
        return nil
    end

    def self.download_missing_series!( seriesid, settings = Settings.new )
        search = Search.new( settings )
        library = Library.new( settings )
        downloads = Downloads.new( settings )

        search.each_series_episode_file_status( seriesid, downloads, library ) do | episode_file |
            if( episode_file.status == :available )
                magnet_link = episode_file.path
                cmd = "open #{magnet_link}"
                puts cmd if settings[:verbose]
                unless settings[:dry_run]
                    system( cmd )
                    sleep( 5 )
                end
            end
        end
    end

    def self.download_missing!( settings = Settings.new )
        search = Search.new( settings )
        library = Library.new( settings )
        downloads = Downloads.new( settings )
        settings[:series].each do | series |
            search.each_series_episode_file_status( series[:id], downloads, library ) do | episode_file |
                if( episode_file.status == :available )
                    magnet_link = episode_file.path
                    cmd = "open #{magnet_link}"
                    puts cmd if settings[:verbose]
                    unless settings[:dry_run]
                        system( cmd )
                        sleep( 5 )
                    end
                end
            end
        end
        # search.each_missing_magnet_link( library ) do | magnet_link |
        #     cmd = "open #{magnet_link}"
        #     puts cmd if settings[:verbose]
        #     unless settings[:dry_run]
        #         system( cmd )
        #         sleep( 5 )
        #     end
        # end
    end


end
