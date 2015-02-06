class Drug

  include DataMapper::Resource

  property :id, Serial
  property :name, String, :length => 100, :unique_index => true
  has n, :hypotheses
  has n, :factoids, :through => :hypotheses

end
