require 'bnet_scraper/starcraft2/base_scraper'
require 'bnet_scraper/starcraft2/profile_scraper'
require 'bnet_scraper/starcraft2/league_scraper'
require 'bnet_scraper/starcraft2/achievement_scraper'
require 'bnet_scraper/starcraft2/match_history_scraper'
require 'bnet_scraper/starcraft2/status_scraper'

module BnetScraper
  # This module contains everything about scraping Starcraft 2 Battle.net accounts.
  # See `BnetScraper::Starcraft2::ProfileScraper` and `BnetScraper::Starcraft2::LeagueScraper`
  # for more details
  module Starcraft2
    REGIONS = {
      'na'  => { gateway: 'us',  subregion: 1, locale: 'en', label: 'North America' },
      'la'  => { gateway: 'us',  subregion: 2, locale: 'en', label: 'Latin America' },
      'eu'  => { gateway: 'eu',  subregion: 1, locale: 'en', label: 'Europe' },
      'ru'  => { gateway: 'eu',  subregion: 2, locale: 'en', label: 'Russia' },
      'cn'  => { gateway: 'cn',  subregion: 1, locale: 'zh', label: 'China' },
      'sea' => { gateway: 'sea', subregion: 1, locale: 'en', label: 'South-East Asia' },
      'tw'  => { gateway: 'tw',  subregion: 1, locale: 'zh', label: 'Taiwan' },
      'kr'  => { gateway: 'kr',  subregion: 1, locale: 'ko', label: 'Korea' },
      # There's a subregion 2 for korea and I honestly don't know what the name of that would be
      'kr2' => { gateway: 'kr',  subregion: 2, locale: 'ko', label: 'Also Korea' }
    }

    # Gateway Hostname Mapping
    # This exists primarily because china does things differently from everyone else.
    HOSTNAMES = {
      'us.battle.net' => 'us',
      'eu.battle.net' => 'eu',
      'www.battlenet.com.cn' => 'cn',
      'cn.battle.net' => 'cn',
      'sea.battle.net' => 'sea',
      'kr.battle.net' => 'kr',
      'tw.battle.net' => 'tw'
    }

    # The armory uses spritemaps that are sequentially named and have a fixed
    # 6x6 grid. We'll simply use the portrait names, left to right, top to
    # bottom.
    #
    # Some names found from http://starcraft.wikia.com/wiki/Portraits
    #
    # All the portraits must have unique names, so that someone who
    # has only the name can reverse this list to get the portrait
    # coordinates.
    #
    PORTRAITS = [
      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/0-75.jpg?v42
      ['Kachinsky', 'Cade', 'Thatcher', 'Hall', 'Tiger Marine', 'Panda Marine', 
      'General Warfield', 'Jim Raynor', 'Arcturus Mengsk', 'Sarah Kerrigan', 'Kate Lockwell', 'Rory Swann', 
      'Egon Stetmann', 'Hill', 'Adjutant', 'Dr. Ariel Hanson', 'Gabriel Tosh', 'Matt Horner', 
      'Tychus Findlay', 'Zeratul', 'Valerian Mengsk', 'Spectre', 'Jim Raynor Marine', 'Tauren Marine',
      'Night Elf Banshee', 'Diablo Marine', 'SCV', 'Firebat', 'Vulture', 'Hellion', 
      'Medic', 'Spartan Company', 'Wraith', 'Diamondback', 'Probe', 'Scout'],

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/1-75.jpg?v42
      ['Korea Tauren Marine', 'Korea Night Elf Banshee', 'Korea Diablo Marine', 'Korea Worgen Marine', 'Korea Goblin Marine', 'PanTerran Marine', 
      'Wizard Templar', 'Tyrael Marine', 'Witch Doctor Zergling', 'Unknown1', 'Night Elf Templar', 'Infested Orc'] +
      (2..25).collect{|x| "Unknown#{x}"},

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/2-75.jpg?v42
      ['Ghost', 'Thor', 'Battlecruiser', 'Nova', 'Zealot', 'Stalker', 
      'Phoenix', 'Immortal', 'Void Ray', 'Colossus', 'Carrier', 'Tassadar',
      'Reaper', 'Sentry', 'Overseer', 'Viking', 'High Templar', 'Mutalisk',
      'Banshee', 'Hybrid Destroyer', 'Dark Voice', 'Unknown26', 'Unknown27', 'Unknown28',
      'Orian', 'Wolf Marine', 'Murloc Marine', 'Unknown29', 'Unknown30', 'Zealot Chef', 
      'Stank', 'Ornatus', 'China Facebook Corps Members', 'China Lion Marines', 'China Dragons', 'Korea Raynor Marine'],

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/3-75.jpg?v42
      ['Urun', 'Nyon', 'Executor', 'Mohandar', 'Selendis', 'Artanis', 
      'Drone', 'Infested Colonist', 'Infested Marine', 'Corruptor', 'Aberration', 'Broodlord', 
      'Overmind', 'Leviathan', 'Overlord', 'Hydralisk Marine', "Zer'atai Dark Templar", 'Goliath', 
      'Lenassa Dark Templar', 'Mira Han', 'Archon', 'Hybrid Reaver', 'Predator', 'Unknown31',
      'Zergling', 'Roach', 'Baneling', 'Hydralisk', 'Queen', 'Infestor', 
      'Ultralisk', 'Queen of Blades', 'Marine', 'Marauder', 'Medivac', 'Siege Tank'],

      # http://media.blizzard.com/sc2/portraits/4-90.jpg
      # level-based rewards, presumably
      (32..67).collect{|x| "Unknown#{x}"}
    ]

    # This is a convenience method that chains calls to ProfileScraper,
    # followed by a scrape of each league returned in the `leagues` array
    # in the profile_data.  The end result is a fully scraped profile with
    # profile and league data in a hash.
    #
    # See `BnetScraper::Starcraft2::ProfileScraper` for more information on
    # the parameters being sent to `#full_profile_scrape`.
    #
    # @param bnet_id - Battle.net Account ID 
    # @param name    - Battle.net Account Name
    # @param gateway - Battle.net Account Gateway
    # @return profile_data - Hash containing complete profile and league data
    #   scraped from the website
    def self.full_profile_scrape bnet_id, name, gateway = 'us'
      profile_scraper = ProfileScraper.new bnet_id: bnet_id, name: name, gateway: gateway
      profile_output  = profile_scraper.scrape

      parsed_leagues = []
      profile_output[:leagues].each do |league|
        league_scraper = LeagueScraper.new url: league[:href]
        parsed_leagues << league_scraper.scrape
      end
      profile_output[:leagues] = parsed_leagues
      return profile_output
    end

    # Determine if Supplied profile is valid.  Useful for validating now before an 
    # async scraping later
    #
    # @param [Hash] options - account information hash
    # @return [TrueClass, FalseClass] valid - whether account is valid
    def self.valid_profile? options
      scraper = BaseScraper.new(options)
      scraper.valid?
    end
  end
end
