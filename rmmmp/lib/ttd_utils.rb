module TTDUtils
  
  def ttd_lines(name)
    unless RUBY_VERSION == '1.8.7'
      File.readlines(name, :encoding => Encoding::UTF_8)[0].split("\r")
    else
      File.readlines(name)[0].split("\r")
    end
  end

end

class TTDLoader
  include TTDUtils

  @@string_to_relation = {
    "sensitivity to" => "efficacy",
    "no relationship with" => "efficacy",
    "resistance to" => "efficacy",
    "toxicity increased for" => "toxicity",
    "toxicity unchanged for" => "toxicity",
    "toxicity decreased for" => "toxicity",
    "synergism with" => "synergism",
    "no synergism with" => "synergism",
    "antagonism with" => "synergism",
    "progression favored by" => "progression"
  }

  @@standard_heads = ["ID", "Source", "Molecule", "Alias (molecule)", "DNA/mRNA/Protein", "State (molecule)",
                    "Modifier", "Alias (modifier)", "Relationship", "Drug (Therapy)", "Alias (drug)", "Model",
                    "H", "Cases", "Reference", "Notes"]
  
  def load(filename)
    #DataMapper::Logger.new(STDOUT, 0)
    lines = ttd_lines(filename)
    labels = lines[0].split("\t")
    unless labels == @@standard_heads
      puts "Input file seems to have the wrong headings! Expected:"
      puts "    #{@@standard_heads.inspect}"
      puts "Found:"
      puts "    #{labels}"
      exit(1)
    end
    Factoid.destroy
    Hypothesis.destroy
    drugs = Set.new
    puts "Loading #{lines.length - 1} records"
    counter = 0
    lines[1..lines.length].each do |line|
      counter += 1
      print '.'
      STDOUT.flush
      if counter >= 100
        puts ""
        counter = 0
      end
      fields = line.split("\t")
      fact_id = fields[0].to_i
      source = fields[1]
      molecule = fields[2]
      molecule_alias = fields[3]
      protein = fields[4]
      molecule_state = fields[5]
      modifier = fields[6]
      modifier_alias = fields[7]
      relationship = fields[8]
      drug_name = fields[9]
      drug_alias = fields[10]
      evidence_type = fields[11].to_i
      h = fields[12].to_i
      cases = fields[13].to_i
      reference = fields[14].gsub(/"/,'')
      notes = fields[15] ? fields[15].gsub(/"/,'') : nil
      relation = @@string_to_relation[fields[8]]
      condition = "#{molecule} #{molecule_state} #{modifier}"
      #drugs << drug
      begin
        # TODO: Deal with drug and modifier aliases
        drug = Drug.first_or_create(:name => drug_name)
        hypothesis = Hypothesis.first_or_create(:relation => relation,
                                                :condition => condition,
                                                :drug => drug)
        hypothesis.save
        f = Factoid.create(:fact_id => fact_id, :source => source, :molecule => molecule,
                       :molecule_alias => molecule_alias, :molecule_state => molecule_state,
                           :modifier => modifier, :modifier_alias => modifier_alias, :relationship => relationship,
                           :condition => condition,
                       :drug_name => drug_name, :drug_alias => drug_alias, :evidence_type => evidence_type, :h => h,
                       :cases => cases, :reference => reference, :notes => notes,
                       :relation => relation, :hypothesis => hypothesis)
        f.save!
      rescue DataMapper::SaveFailureError => e
        puts "#{e.message}"
        e.resource.errors.each do |r|
          puts "#{r}"
        end
      end
      drug.hypotheses << hypothesis
    end
    puts ''
    ['efficacy', 'toxicity', 'synergism', 'progression'].each {|r| Hypothesis.summarize_evidence_initial(r)}
    puts "done"
    STDOUT.flush
  end
  
end

module Enumerable
  def dups
    inject(Hash.new(0)) {|h,v| h[v] += 1; h}.reject{|k,v| v==1}.keys
  end
end
