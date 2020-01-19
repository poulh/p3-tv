# frozen_string_literal: true

module P3
  module TV
    class EpisodeFile
      attr_accessor :series_id, :series, :season, :episode, :title, :air_date, :path, :status, :percent_done, :thumbnail
      attr_writer :type

      def initialize(series, episode)
        @series_id = series[:id]
        @series = series[:name]
        @season = episode[:season_number]
        @episode = episode[:number]
        @path = episode[:path]
      end

      def type
        unless @type
          if @path
            ext = File.extname(@path)
            @type = ext unless ext.empty?
          end
        end
        @type
      end

      def to_json(*a)
        to_h.to_json(*a)
      end

      def to_h
        { series_id: series_id,
          series: series,
          season: season,
          episode: episode,
          title: title,
          air_date: air_date.to_s,
          path: path,
          status: status,
          percent_done: percent_done,
          thumbnail: thumbnail }
      end

      def <=>(other)
        if series == other.series
          if season == other.season
            episode <=> other.episode
          else
            season <=> other.season
          end
        else
          series <=> other.series
        end
      end

      def to_s
        to_h.to_s
      end
    end
  end
end
