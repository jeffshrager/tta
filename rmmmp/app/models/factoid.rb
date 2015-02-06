class Factoid

  include DataMapper::Resource

  property :id, Serial

  belongs_to :hypothesis

  property :fact_id, Integer
  property :source, String
  property :molecule, String, :length => 255
  property :molecule_alias, String, :length => 100
  property :molecule_state, String
  property :modifier, String
  property :modifier_alias, String, :length => 100
  property :condition, String, :index => true, :length => 255
  property :relationship, String
  property :drug_name, String, :length => 100
  property :drug_alias, String, :length => 100
  property :evidence_type, Integer
  property :h, Integer
  property :cases, Integer
  property :reference, Text
  property :notes, Text
  property :relation, String

  def cleanup(field, sep)
    field.gsub(/"/,'').split(sep).collect {|i| i.strip}
  end

  @@evidence_type_strings = [
    "animal, in vitro",
    "animal, in vivo",
    "human, in vitro",
    "human xenograft",
    "clinical study / non randomized clinical trial",
    "randomized controlled trial",
    "meta-analysis"
  ]

  def evidence_type_string
    @@evidence_type_strings[self.evidence_type - 1]
  end

  def clean_molecules
    [cleanup(self.molecule, ','), cleanup(self.molecule_alias, ',')].flatten.uniq
  end
  
  def clean_drugs
    [cleanup(self.drug_name, '+'), cleanup(self.drug_alias, '+')].flatten.uniq
  end

  def self.molecules_for_drugs(drugs)
    all(:drug => drugs, :fields=>[:id, :molecule, :molecule_state], :order=>[:molecule.asc, :molecule_state])
  end

  def self.drugs_for_molecules(molecules)
    all(:molecule => molecules, :fields => [:drug_name, :drug_alias], :unique => true).collect {|f| f.clean_drugs}.flatten.uniq.sort
end

end
