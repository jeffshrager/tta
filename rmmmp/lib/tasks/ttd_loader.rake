require 'ttd_utils.rb'

namespace :mmmp do

  desc "Load the TTD from a tab-separated file"
  task :load_ttd => :environment do
    loader = TTDLoader.new
    loader.load('TargetedTherapyDatabase_TTD.txt')
  end

end
