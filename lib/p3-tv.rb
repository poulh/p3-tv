# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open-uri'

require 'p3-eztv'
require 'p3-tvdb'
require 'p3-transmission'

require 'p3-tv/episode_file'
require 'p3-tv/settings'
require 'p3-tv/library'
require 'p3-tv/search'
require 'p3-tv/downloads'

module P3
  module TV
    def self.format_title(title)
      # strip non alphanumeric characters and extra whitespace
      rval = title.gsub(/[^0-9a-z ]/i, '').gsub(/[ ]+/, ' ').strip
      rval
    end

    def self.path_contains_series?(path, title)
      formatted_title = P3::TV.format_title(title)
      if path.scan(/#{formatted_title}/i).empty? # case insensative
        return false if path.scan(/#{formatted_title.gsub(' ', '.')}/i).empty? # Titles.With.Periods.Instead.Of.Spaces
      end
      true
    end

    def self.add_series!(title)
      settings = Settings.new
      search = Search.new(settings)

      results = search.find_series(title)

      settings.add_series!(results[0])
      settings.save!
    end

    def self.test_mode_enabled?
      settings = Settings.new
      (settings[:verbose] && settings[:dry_run])
    end

    def self.enable_test_mode!(enable)
      Settings.set!(:dry_run, enable)
      Settings.set!(:verbose, enable)
    end

    def self.catalog_file!(path, settings = Settings.new)
      downloads = Downloads.new(settings)
      return if settings.allowed_type?(path)

      library = Library.new(settings)
      episode = downloads.create_episode_from_filename(path)
      library.catalog!(episode) if episode
      nil
    end

    def self.catalog_downloads_series!(seriesid, settings = Settings.new)
      downloads = Downloads.new(settings)
      downloads.remove_completed_torrents!

      library = Library.new(settings)
      downloads.each_episode_file_in_series(seriesid) do |episode_file|
        library.catalog!(episode_file)
      end
      nil
    end

    def self.catalog_downloads!(settings = Settings.new, downloads = Downloads.new(settings))
      library = Library.new(settings)
      downloads.each_episode_file do |episode_file|
        library.catalog!(episode_file)
      end
      nil
    end

    def self.download_missing_series!(seriesid, settings = Settings.new)
      search = Search.new(settings)
      library = Library.new(settings)
      downloads = Downloads.new(settings)

      settings.each_series_episode_file_status(seriesid, search, downloads, library) do |episode_file|
        downloads.download_episode_file!(episode_file)
      end
    end

    def self.download_missing!(settings = Settings.new)
      search = Search.new(settings)
      library = Library.new(settings)
      downloads = Downloads.new(settings)
      settings[:series].each do |series|
        settings.each_series_episode_file_status(series[:id], search, downloads, library) do |episode_file|
          downloads.download_episode_file!(episode_file)
        end
      end
    end
  end
end
