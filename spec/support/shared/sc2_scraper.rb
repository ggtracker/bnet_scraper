shared_examples 'an SC2 Scraper' do
  describe '#initialize' do
    context 'with url parameter passed' do
      it 'should extract bnet_id from the URL' do
        subject.bnet_id.should == '2377239' 
      end

      it 'should extract name from the URL' do
        subject.name.should == 'Demon'
      end

      it 'should extract the subregion from the URL' do
        subject.subregion.should == 1
      end

      it 'should extract the gateway from the URL' do
        subject.gateway.should == 'us'
      end

      it 'should identify the region from gateway and subregion' do
        subject.region.should == 'na'
      end
    end

    context 'when bnet_id and name parameters are passed' do
      subject { scraper_class.new(bnet_id: '2377239', name: 'Demon') }
      it 'should set the bnet_id and name parameters' do
        subject.bnet_id.should == '2377239'
        subject.name.should == 'Demon'
      end

      it 'should default the gateway to us' do
        subject.gateway.should == 'us'
      end

      it 'should default the subregion to 1' do
        subject.subregion.should == 1
      end
    end
  end

  describe '#region_info' do
    it 'should return information based on the set region' do
      subject.region_info.should == { gateway: 'us',  subregion: 1, locale: 'en', label: 'North America' }
    end
  end

  describe '#profile_url' do
    it 'should return a string URL for bnet' do
      subject.profile_url.should == 'http://us.battle.net/sc2/en/profile/2377239/1/Demon/'
    end
  end

  describe '#valid?' do
    it 'should return true when profile is valid' do
      result = subject.valid?
      result.should be_true
    end

    it 'should return false when profile is invalid' do
      scraper = scraper_class.new(url: 'http://us.battle.net/sc2/en/profile/2377239/1/SomeDude/')

      result = scraper.valid?
      result.should be_false
    end
  end
end
