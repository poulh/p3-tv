# frozen_string_literal: true

module P3
  module TV
    # a mixture of Torrent download status and checking the file once downloaded
    class Downloads
      REGEX = [/[sS](\d{1,2})[eE][pP]?(\d{1,2})/, # s1e2, s01e02, S1E02, S01E2, s01ep2
               /(\d{1,2})x(\d{1,2})/].freeze # 1x2, 01x2, 1x02, 01x02.freeze

      def initialize(settings = Settings.new)
        @settings = settings
        @transmission = nil

        @torrents = nil
      end

      def self.extract_episode_from_path(path)
        REGEX.each do |regex|
          match_data = path.match(regex)
          if match_data
            return {
              season_number: match_data[1].to_i,
              number: match_data[2].to_i,
              path: path
            }
          end
        end
        nil
      end

      def extract_series_episode_from_path(path)
        @settings[:series].each do |series|
          series_name = series[:name]
          next unless P3::TV.path_contains_series?(path, series_name)

          episode_hash = Downloads.extract_episode_from_path(path)
          return { series: series, episode: episode_hash } if episode_hash
        end
        nil
      end

      def create_episode_from_path_series(path, series_id, series_name)
        return nil unless P3::TV.path_contains_series?(path, series_name)

        series_hash = { id: series_id, name: series_name }
        episode_hash = extract_episode_from_path(path)
        return EpisodeFile.new(series_hash, episode_hash) if episode_hash

        nil
      end

      def create_episode_from_path(path)
        series_episode_hash = extract_series_episode_from_path(path)

        if series_episode_hash
          series_hash = series_episode_hash[:series]
          episode_hash = series_episode_hash[:episode]
          return EpisodeFile.new(series_hash, episode_hash)
        end

        nil
      end

      def each_episode_file_in_series(seriesid)
        series = @settings.get_series(seriesid)
        if series
          episode_files = paths.collect { |path| create_episode_from_path_series(path, series[:id], series[:name]) }
          episode_files.each do |episode_file|
            yield(episode_file) if episode_file
          end
        end
      end

      def episode_files
        episode_files = @settings.supported_paths_in_dir.collect do |path|
          create_episode_from_path(path)
        end

        episode_files.compact.collect do |episode_file|
          episode_file.status = :downloaded
          episode_file.percent_done = 1
          episode_file
        end
      end

      def each_downloading_file
        torrents.each do |torrent|
          path = torrent['name']
          episode_file = create_episode_from_path(path)
          next unless episode_file

          episode_file.status = :downloading
          episode_file.percent_done = torrent['percentDone']
          yield(episode_file)
        end
      end

      def download!(path)
        if transmission
          transmission.create(path)
        else
          cmd = "open #{path}"
          cmd = "xdg-#{cmd} 2>/dev/null" if Gem::Platform.local.os == 'linux'
          system(cmd)
        end
      end

      def download_episode_file!(episode_file)
        if episode_file.status == :available
          magnet_link = episode_file.path
          puts magnet_link if @settings[:verbose]
          download!(magnet_link) unless @settings[:dry_run]
        end
      end

      def transmission
        unless @transmission
          config = {}
          %i[transmission_username transmission_password transmission_host transmission_port].each do |transmission_key|
            return @transmission unless @settings[transmission_key]

            key = transmission_key.to_s.gsub('transmission_', '').to_sym
            config[key] = @settings[transmission_key]
          end

          @transmission = P3::Transmission::Client.new(config)
        end

        @transmission
      end

      def torrents
        @torrents = [] unless transmission
        @torrents ||= transmission.all

        @torrents
      end

      def remove_completed_torrents!
        count = 0
        torrents.each do |torrent|
          count += 1
          transmission.remove(torrent['id']) if torrent['percentDone'] == 1
        end

        torrents.reject! { |torrent| torrent['percentDone'] == 1 }
        count
      end

      def get_path_if_exists(episode_file)
        episode_files = paths.collect { |path| create_episode_from_path_series(path, episode_file.series_id, episode_file.series) }
        episode_files.select! { |ef| ef }
        episode_files.each do |dn_ep| # download_episode_file
          return dn_ep.path if (episode_file <=> dn_ep) == 0
        end
        nil
      end

      def get_torrent_if_exists(episode_file)
        torrents.each do |torrent|
          path = torrent['name']
          torrent_episode = create_episode_from_path_series(path, episode_file.series_id, episode_file.series)
          next unless torrent_episode
          return torrent if (episode_file <=> torrent_episode) == 0
        end
        nil
      end
  end
  end
end
