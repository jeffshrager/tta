module DrugsHelper
  RELATIONSHIP_MAPPING = {
      "efficacy"=>   { -1=>"resistance to" ,            0=>"no relationship to",       1=>"sensitivity to"},
      "toxicity"=>   { -1=>"toxicity increased for",    0=>"toxicity unchanged for",   1=>"toxicity decreased for"},
      "synergism"=>  { -1=>"synergism with",           0=>"no synergy with",          1=>"antagonism with"},
      "progression"=>{ -1=>"progression favored by",    0=>"progression unchanged by", 1=>"progression slowed by"}
  }

  def translate_prevalence(relation,prevalence)
    RELATIONSHIP_MAPPING[relation][prevalence]
  end
end
