# frozen_string_literal: true

module P3
  module TV
    class Library
      def initialize(settings = Settings.new)
        @settings = settings
      end

      def exists?(episode)
        Dir.glob(episode_glob(episode)).each do |path|
          return true if File.exist?(path)
        end
        false
      end

      def format_season(episode)
        episode.season.to_s.rjust(2, '0')
      end

      def format_episode(episode)
        episode.episode.to_s.rjust(2, '0')
      end

      def episode_glob(episode)
        formatted_title = P3::TV.format_title(episode.series)
        File.join(@settings[:library_path],
                  formatted_title,
                  "Season #{format_season(episode)}",
                  "#{formatted_title} S#{format_season(episode)}E#{format_episode(episode)}" + (episode.type || '.*'))
      end

      def episode_path(episode)
        glob = episode_glob(episode)
        if episode.type
          return glob # this will NOT end in .*
        else
          Dir.glob(glob).each do |path|
            return path
          end
        end
      end

      def catalog!(episode)
        cataloged_path = episode_path(episode)
        cataloged_dir = File.dirname(cataloged_path)
        dry_run = @settings[:dry_run]
        verbose = @settings[:verbose]
        episode_path = episode.path

        unless File.exist?(cataloged_dir)
          FileUtils.mkdir_p(cataloged_dir, noop: dry_run, verbose: verbose)
        end

        if !File.exist?(cataloged_path) || @settings[:overwrite_duplicates]
          FileUtils.move(episode_path, cataloged_path,
                         noop: dry_run, verbose: verbose, force: true)
        elsif @settings[:delete_duplicate_downloads]
          FileUtils.remove(episode_path, noop: dry_run, verbose: verbose)
        elsif verbose
          warn "file exists. doing nothing: #{cataloged_path}"
        end
      end
    end
  end
end
