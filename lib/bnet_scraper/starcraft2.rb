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
    # Note: I couldn't identify the exact names of some of these and instead of
    # guessing, I didn't name them. Some appear in multiple files too, which 
    # is odd.
    #
    # I decided th pad the arrays even if there are no images to make various
    # helping functionality (e.g. retrieving position for a name) easier.
    # I've also kept them in 6x6 here for better overview.
    PORTRAITS = [
      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/0-75.jpg?v42
      ['Kachinsky', 'Cade', 'Thatcher', 'Hall', 'Tiger Marine', 'Panda Marine', 
      'General Warfield', 'Jim Raynor', 'Arcturus Mengsk', 'Sarah Kerrigan', 'Kate Lockwell', 'Rory Swann', 
      'Egon Stetmann', 'Hill', 'Adjutant', 'Dr. Ariel Hanson', 'Gabriel Tosh', 'Matt Horner', 
      # Could not identify in order: Raynor in a Suit? Bullmarine? Nova? 
      # Fiery Marine?
      'Tychus Findlay', 'Zeratul', 'Valerian Mengsk', 'Spectre', '?', '?',
      '?', '?', 'SCV', 'Firebat', 'Vulture', 'Hellion', 
      'Medic', 'Spartan Company', 'Wraith', 'Diamondback', 'Probe', 'Scout'],

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/1-75.jpg?v42
      # Special Rewards - couldn't identify most of these.
      ['?', '?', '?', '?', '?', 'PanTerran Marine', 
      '?', '?', '?', '?', '', '',
      '', '', '', '', '', '',
      '', '', '', '', '', '',
      '', '', '', '', '', '',
      '', '', '', '', '', ''],

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/2-75.jpg?v42
      ['Ghost', 'Thor', 'Battlecruiser', 'Nova', 'Zealot', 'Stalker', 
      'Phoenix', 'Immortal', 'Void Ray', 'Colossus', 'Carrier', 'Tassadar',
      'Reaper', 'Sentry', 'Overseer', 'Viking', 'High Templar', 'Mutalisk',
      # Unidentified: Bird? Dog? Robot?
      'Banshee', 'Hybrid Destroyer', 'Dark Voice', '?', '?', '?',
      # Unidentified: Worgen? Goblin? Chef?
      'Orian', 'Wolf Marine', 'Murloc Marine', '?', '?', 'Zealot Chef', 
      # Unidentified: KISS Marine? Dragon Marine? Dragon? Another Raynor?
      'Stank', 'Ornatus', '?', '?', '?', '?'],

      # http://eu.battle.net/sc2/static/local-common/images/sc2/portraits/3-75.jpg?v42
      ['Urun', 'Nyon', 'Executor', 'Mohandar', 'Selendis', 'Artanis', 
      'Drone', 'Infested Colonist', 'Infested Marine', 'Corruptor', 'Aberration', 'Broodlord', 
      'Overmind', 'Leviathan', 'Overlord', 'Hydralisk Marine', "Zer'atai Dark Templar", 'Goliath', 
      # Unidentified: Satan Marine?
      'Lenassa Dark Templar', 'Mira Han', 'Archon', 'Hybrid Reaver', 'Predator', '?',
      'Zergling', 'Roach', 'Baneling', 'Hydralisk', 'Queen', 'Infestor', 
      'Ultralisk', 'Queen of Blades', 'Marine', 'Marauder', 'Medivac', 'Siege Tank']
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
