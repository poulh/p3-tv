# frozen_string_literal: true

# Namespace for library
module P3
  module TV
    class Search
      # please don't steal my key. it is very easy to get one for your
      # app here: http://thetvdb.com/index.php?tab=apiregister
      # they won't spam you and its free
      TVDB_API_KEY = '70BE8DAF03F45D4A'

      def initialize(settings = Settings.new)
        @settings = settings

        @tvdb = P3::Tvdb::Search.new(TVDB_API_KEY)
        @eztv = {}
      end

      def find_series(title)
        results = @tvdb.search(title)
        results.select! { |r| r['FirstAired'] } # must have this field

        # assume the more-recent show first
        results.sort! { |a, b| b['FirstAired'] <=> a['FirstAired'] }
        results = results.collect { |r| find_series_by_id(r['seriesid']) }
        results
      end

      def find_series_by_id(seriesid)
        @tvdb.get_series_by_id(seriesid)
      end

      def find_episodes_by_seriesid(seriesid)
        series = find_series_by_id(seriesid)
        series&.episodes&.each do |episode|
          yield(episode) if episode.season_number > 0
        end
      end

      def each_episode
        @settings[:series].each do |series_hash|
          find_episodes_by_seriesid(series_hash[:id]) do |episode|
            yield(episode)
          end
        end
      end

      def eztv(series_name)
        unless @eztv.key?(series_name)
          ez = P3::Eztv::Series.new(P3::TV.format_title(series_name))
          ez.high_def! if @settings[:high_def]
          @eztv[series_name] = ez
        end
        @eztv[series_name]
      end

      def get_magnet_link_if_exists(episode_file)
        ez = eztv(episode_file.series)
        eztv_episode = ez.episode(episode_file.season, episode_file.episode)
        return eztv_episode.magnet_link if eztv_episode

        nil
      end
  end
    end
  end
