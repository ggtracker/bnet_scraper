module BnetScraper
  module Starcraft2
    # BaseScraper handles the account information extraction. Each scraper can either be passed a profile URL or
    # the minimum information needed to access an account: bnet_id and name. The gateway will default to 'us'
    # and region will default to the first region for the given gateway.
    #
    # Both of the following are valid ways to instantiate a scraper for the same account:
    #
    #   BnetScraper::Starcraft2::BaseScraper.new(url: 'http://us.battle.net/sc2/en/profile/12345/1/TestAccount/')
    #   BnetScraper::Starcraft2::BaseScraper.new(bnet_id: '12345', name: 'TestAccount')
    #
    # The URL scheme is the following:
    #   http://<gateway>.battle.net/sc2/<locale>/profile/<bnet_id>/<region>/<name>/
    class BaseScraper
      attr_reader :bnet_id, :name, :gateway, :subregion, :region, :url

      def initialize options = {}
        if options[:url]
          extracted_data = options[:url].match(/http:\/\/(.+)\/sc2\/(.+)\/profile\/(.+)\/(\d{1})\/(.[^\/]+)\//)
          if extracted_data
            @hostname   = extracted_data[1]
            @gateway    = HOSTNAMES[@hostname]
            @locale     = extracted_data[2]
            @bnet_id    = extracted_data[3]
            @subregion  = extracted_data[4].to_i
            @name       = extracted_data[5]
            @url        = options[:url]
          else
            raise BnetScraper::InvalidProfileError, "URL provided does not match Battle.net format"
          end
        elsif options[:bnet_id] && options[:name]
          @bnet_id  = options[:bnet_id]
          @name     = options[:name]
          @gateway  = options[:gateway] || 'us'
          @subregion= (options[:subregion] || 1).to_i
        else
          raise BnetScraper::InvalidProfileError, "Required options missing"
        end
        
        @region = REGIONS.find{|region, data| data[:gateway] == @gateway && data[:subregion] == @subregion}
        raise BnetScraper::InvalidProfileError, "Could not identify region from gateway '#{@gateway}' and subregion '#{@subregion}'" if !@region
        @region = @region[0]
      end

      # Returns the profile URL generated from associated data
      # Note: while China has it's own hostname/domain, cn.battle.net will
      # redirect to it properly.
      def profile_url
        "http://#{gateway}.battle.net/sc2/#{region_info[:locale]}/profile/#{bnet_id}/#{region_info[:subregion]}/#{name}/"
      end

      def region_info
        REGIONS[region]
      end

      def valid?
        result = Faraday.get profile_url
        result.success?
      end

      def scrape
        raise NotImplementedError, "Abstract method #scrape called."
      end
    end
  end
end
