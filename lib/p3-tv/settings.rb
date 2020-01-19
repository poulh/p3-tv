# Namespace for library
module P3
  module TV
    # Settings for P3 TV
    class Settings
      attr_accessor :path 
      DEFAULT_PATH = File::expand_path( "~/.p3tv/p3tv" )
      EPISODES_JSON = 'episodes.json'
      DEFAULTS = {
        :library_path => '~/Movies/P3TV',
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
        File::exist?( path )
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
        @episodes = {}
        return unless File::exists?( @path )

        FileUtils::mkdir_p( File::dirname( @path ) )

        f = File::open( @path, 'r' )
        @values = JSON.parse(f.read, symbolize_names: true)
        
        f.close

        self[:library_path] = File::expand_path( self[:library_path ] )
        FileUtils::mkdir_p( self[:library_path] )

        self[:download_path] = File::expand_path( self[:download_path ] )
        self[:series].uniq!

        if( self[:overwrite_duplicates] and self[:delete_duplicate_downloads] )
            raise "you cannot have 'overwrite_duplicates' and 'delete_duplicate_downloads' both set to true"
        end
      end

      def to_h
        @values
      end

      def []( key )
        @values[ key.to_sym ]
      end

      def []=( key, value )
        @values[ key.to_sym ] = value
        self.save!
      end

      def supported_paths_in_dir(dir = self[:download_path])
        glob = File.join(dir, '**/*')
        all_file_paths = Dir.glob(glob)
        all_file_paths.select do |file_path|
          supported_file_extension?(file_path)
        end
      end

      def supported_file_extension?(path)
        return ( self[:allowed_types].include?( File::extname( path ) ) or self[:allowed_types].include?( File::extname( path ) ) )
      end

      def get_series( seriesid )
        return self[:series].detect{|s| s[:id] == seriesid }
      end

      def download_url!( url, path )
        # http://stackoverflow.com/questions/2515931/how-can-i-download-a-file-from-a-url-and-save-it-in-rails
        return path if File::exists?( path )
        begin
            download = open( url )
            IO.copy_stream( download, path )
        rescue => e
            return ""
        end
        return path
      end

      def download_banners!( banners, path )
        FileUtils::mkdir_p( File::dirname( path ) )
        return if banners.empty?
        banner = banners.detect{|b| b.url.length }
        return "" unless banner

        return download_url!( banner.url, path )
      end

      def episodes( seriesid )
        unless @episodes.has_key?( seriesid )
            episode_file = File::join( series_dir( seriesid ), EPISODES_JSON )
            if( File::exists?( episode_file ) )
                f = File::open( episode_file )
                @episodes[ seriesid ] = JSON::parse( f.read, :symbolize_names => true )
            end
        end
        return @episodes[ seriesid ]
      end

      def each_series_episode_file_status( seriesid, search, downloads, library )
        today = Date::today.to_s

        series_hash = self[:series].detect{|s| s[:id] == seriesid}
        return unless series_hash

        episodes( seriesid ).each do | episode_hash |
            next if episode_hash[:season_number] == 0
            ep_file = P3::TV::EpisodeFile.new
            ep_file.series_id = episode_hash[:id]
            ep_file.series = series_hash[:name]
            ep_file.season = episode_hash[:season_number]
            ep_file.episode = episode_hash[:number]
            ep_file.title = episode_hash[:name]
            ep_file.air_date = episode_hash[:air_date]
            ep_file.thumbnail = episode_hash[:thumb_path]

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
            elsif( magnet_link = search.get_magnet_link_if_exists( ep_file ) )
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


      def series_dir( seriesid )
          return File::join( File::dirname( @path ), 'series', seriesid )
      end

      def download_episodes!( series )
        meta_path = series_dir( series.id )
        episodes = []
        series.episodes.each do |episode|
            episode_hash = episode.to_h
            episode_hash[:thumb_path] = download_url!( episode_hash[:thumb], File::join( meta_path, "#{episode.id}.jpg" ) )
            episodes << episode_hash
        end
        f = File::open( File::join( meta_path, EPISODES_JSON ), 'w' )
        f.puts JSON::pretty_generate( episodes )
        f.close()

        @episodes.delete( series.id ) #clear the cache
      end

      def add_series!( series )
        meta_path = series_dir( series.id )

        hash = series.to_h
        hash[:banners] = {}
        hash[:banners][:poster] = download_banners!(series.posters( self[:language] ),  File::join( meta_path, 'poster.jpg' ) )
        hash[:banners][:banner] = download_banners!( series.series_banners( self[:language] ),  File::join( meta_path, 'banner.jpg' ) )

        download_episodes!( series )

        remove_series!( hash[:id] )
        self[:series] << hash
        leading_the = /^The /
        self[:series].sort!{|a,b| a[:name].gsub(leading_the,'') <=> b[:name].gsub(leading_the,'') }
        self.save!
      end

      def update_series!( series )
        return unless series.status == "Continuing"

        ep = self.episodes( series.id )
        return unless( ep )

        ep.select!{|e| e[:air_date] }
        ep.sort!{|a,b| b[:air_date] <=> a[:air_date] } #newest episode first

        today = Date::today.to_s
        if( ep.empty? or ( ep[0][:air_date] < today ) )
            download_episodes!( series )
        end
      end

      def remove_series!( seriesid )
        self[:series].reject!{|s| s[:id] == seriesid }
        self.save!
      end

      def save!
        f = File::open( @path, 'w' )
        f.puts( JSON::pretty_generate( @values ) )
        f.close
      end
    end
  end
end
