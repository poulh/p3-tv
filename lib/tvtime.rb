require 'fileutils'
require 'json'
require 'open-uri'

require 'p3-eztv'
require 'p3-tvdb'
require 'transmission_api'

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
            :language => 'en',
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

        def to_h
            return @values
        end

        def []( key )
            return @values[ key ]
        end

        def []=( key, value )
            @values[ key ] = value
        end

        def allowed_type?( path )
            return ( self[:allowed_types].include?( File::extname( path ) ) or self[:subtitles].include?( File::extname( path ) ) )
        end

        def get_series( seriesid )
            return self[:series].detect{|s| s[:id] == seriesid }
        end

        def download_banners!( banners, path )
            FileUtils::mkdir_p( File::dirname( path ) )
            return if banners.empty?
            banner = banners.detect{|b| b.url.length }
            return unless banner

            begin
                # http://stackoverflow.com/questions/2515931/how-can-i-download-a-file-from-a-url-and-save-it-in-rails
                download = open( banner.url )
                IO.copy_stream( download, path )
            rescue => e
                return ""
            end

            return path
        end

        def add_series!( series )
            hash = series.to_h
            hash[:banners] = {}
            meta_path = [ File::dirname( @path ), 'series', hash[:id] ].join( File::SEPARATOR )
            hash[:banners][:poster] = download_banners!( series.posters( self[:language] ),  [ meta_path, 'poster.jpg' ].join( File::SEPARATOR ) )
            hash[:banners][:banner] = download_banners!( series.series_banners( self[:language] ),  [ meta_path, 'banner.jpg' ].join( File::SEPARATOR ) )

            remove_series!( hash[:id] )
            self[:series] << hash
            leading_the = /^The /
            self[:series].sort!{|a,b| a[:name].gsub(leading_the,'') <=> b[:name].gsub(leading_the,'') }
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
        attr_accessor :series_id, :series, :season, :episode, :title, :air_date, :path, :status, :percent_done
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
            return { :series_id => series_id,
                     :series => series,
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

        def path_match_series( path, series_name )
            return unless( ::TVTime::path_contains_series?( path, series_name ) )
            REGEX.each do | regex |
                match_data = path.match( regex )
                if( match_data )
                    yield( match_data )
                    return
                end
            end
        end

        def path_match( path )
            @settings[:series].each do | series |
                path_match_series( path, series[:name] ) do | match_data |
                    yield( series, match_data )
                    return
                end
            end
        end

        def create_episode_from_filename_series( path, seriesid, series_name )
            e = nil
            path_match_series( path, series_name ) do | match_data |
                e = EpisodeFile.new
                e.series_id = seriesid
                e.series = series_name
                e.season = match_data[1].to_i
                e.episode = match_data[ 2 ].to_i
                e.path = path
            end
            return e
        end

        def create_episode_from_filename( path )
            e = nil
            path_match( path ) do | series, match_data |
                e = EpisodeFile.new
                e.series_id = series[:id]
                e.series = series[:name]
                e.season = match_data[1].to_i
                e.episode = match_data[ 2 ].to_i
                e.path = path
            end
            return e
        end

        def each_episode_file_in_series( seriesid )
            series = @settings.get_series( seriesid )
            if( series )
                episode_files = paths().collect{|path| create_episode_from_filename_series( path, series[:id], series[:name] ) }
                episode_files.each do | episode_file |
                    yield( episode_file ) if episode_file
                end
            end
        end

        def each_episode_file
            episode_files = paths().collect{|path| create_episode_from_filename( path ) }
            episode_files.each do | episode_file |
                if episode_file
                    episode_file.status = :downloaded
                    episode_file.percent_done = 1
                    yield( episode_file )
                end
            end

        end

        def each_downloading_file
            torrents().each do |torrent|
                episode_file = create_episode_from_filename( torrent['name'] )
                if( episode_file )
                    episode_file.status = :downloading
                    episode_file.percent_done = torrent['percentDone']
                    yield( episode_file )
                end
            end
        end

        def paths
            return @paths if @paths
            glob = [ @settings[:download_path], '**/*' ].join( File::SEPARATOR )
            @paths = Dir::glob( glob )
            @paths = @paths.select{|p| @settings.allowed_type?( p ) }
            return @paths
        end

        def transmission
            unless @transmission
                unless( @settings[:transmission] == nil )
                    @transmission = TransmissionApi::Client.new(@settings[:transmission])
                end
            end

            return @transmission
        end

        def torrents
            @torrents = [] unless transmission()
            unless @torrents
                @torrents = transmission().all
            end

            return @torrents
        end

        def remove_completed_torrents!
            count = 0
            torrents().each do | torrent |
                count += 1
                transmission().remove( torrent['id'] ) if torrent['percentDone'] == 1
            end

            torrents().reject!{ | torrent | torrent['percentDone'] == 1 }
            return count
        end

        def get_path_if_exists( episode_file )
            episode_files = paths().collect{|p| create_episode_from_filename_series( p, episode_file.series_id, episode_file.series ) }
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
                torrent_episode = create_episode_from_filename_series( name, episode_file.series_id, episode_file.series )
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
        #strip non alphanumeric characters and extra whitespace
        rval = title.gsub(/[^0-9a-z ]/i, '').gsub(/[ ]+/,' ').strip
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
            raise "tvdb api key required" unless @settings[:tvdb_api_key]
            @tvdb = P3::Tvdb::Search.new( @settings[:tvdb_api_key] )
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
            if( series )
                series.episodes.each do | episode |
                    yield( episode ) if episode.season_number.to_i > 0
                end
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
                ep_file.series_id = seriesid
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
                ez = P3::Eztv::Series.new( ::TVTime::format_title( series_name ) )
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
        return if settings.allowed_type?( path )
        library = Library.new( settings )
        episode = downloads.create_episode_from_filename( path )
        library.catalog!( episode ) if episode
        return nil
    end

    def self.catalog_downloads_series!( seriesid, settings = Settings.new )
        downloads = Downloads.new( settings )
        downloads.remove_completed_torrents!

        library = Library.new( settings )
        downloads.each_episode_file_in_series( seriesid ) do | episode_file |
            library.catalog!( episode_file )
        end
        return nil
    end


    def self.catalog_downloads!( settings = Settings.new, downloads = Downloads.new( settings ) )
        library = Library.new( settings )
        downloads.each_episode_file do | episode_file |
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
