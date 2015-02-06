=begin

Prevalent hypothesis computation:
-------------------
Relation type = efficacy / toxicity / synergism
Hypothesis [hyp] = 1 if associated with increase in [relation type], -1 if associated with decrease, 0 if no effect

"Condition" = drug/molecule/state(relation type)

These are computed from a single row of the input spreadsheet, so could be precomputed:
 - Model score [MS] = case(model) of 6,12,24,48,96,192,384 (i.e., 6*2^model)
 - Size score [SS] = cases/10
 - Adjusted size score [SSa] = 1 if size score=0, else size score
 - Evidence score [ES] = MS * SSa

For each Condition matching item:
 - Sensitivity score [SeS] = ES if hyp=1, else 0
 - Resistance score [ReS] = ES if hyp=-1, else 0
 - Null score [NuS] = ES if hyp=0, else 0

 - For all following, i is minus, null, plus [m, n, p] (-1, 0, 1)

 - Evidence score(plus) [ESp] = sum of plus scores
 - Evidence score(minus) [ESm] = sum of minus scores
 - Evidence score(null) [ESn] = sum of null scores
 - Total score [TS] = abs(ESp) + abs(ESm) + abs(ESn)
 - Score percentage [SPi] = ESi / TS (i in p, m, n (i.e., calc for each evidence score))

 - Agresti-Coull method corrected scores:
   - Corrected evidence score [ESic]  = evidence score + (1.96^2 / 2)
   - Corrected total score [TSc] = total score + (1.96^2)
   - Corrected score percentage [SPic] = ESic / TSc

 - Variance [Vi] = (SPic * (1 - abs(SPic))) / abs(TSc)
 - Standard error [SEi] = sqrt(Vi)

 - Score percentage 95% confidence interval limits:
   - upper [CLui] = SPic + (1.96 * SEi)
   - lower [CLli] = SPic - (1.96 * SEi)

 - Z score:
   - Zi = (SPi - criterion) / SEi [note: NOT corrected SP, but SE uses corrected version!]

"Prevalent" flag = 1 if Z score > criterion (default is 0.5) for either plus or minus effect, 0 if
 none of the three above 0.5, or null > 0.5 (Z score = (score percentage - 0.5) / standard error)
 - PH = (Zs > criterion) || (Zr > criterion) || (Zn !> 0.5)
-------------------

Following the process described above, we have a set of hypotheses, each corresponding to a unique
set of [Condition, drug].

Profile matching (for one drug):
-------------------
Patient results are a set of [Condition, concordance] pairs, where concordance is 1, 0, or -1
depending on whether each Condition test result was positive, inconclusive (or missing), or negative.
Results with a concordance of 0 can be discarded.
Relevant hypotheses are first grouped by drug. For each hypothesis being considered:
Weight = 1 / abs(Vj) [where j indexes a [molecule, state] pairing that matches one of the results supplied]
Score percentage for profile matching is multiplied by concordance (this is where the zero results disappear), so:
Wj * SPj = Weight * profile matching score percentage, with sign determined by concordance or discordance with
the prevalent hypothesis (multiply by -1 for discordance).

Overall score [OS] =  sum of W*SP values across molecules / sum of weights across molecules
Overall score variance [Vo] = 1 / sum of Wi's
Overall score standard error [SEo] = sqrt(Vo)
OS 95% confidence interval upper limit = OS + (1.96 * SEo)
OS 95% confidence interval lower limit = OS - (1.96 * SEo)

If overall score > threshold and 95% confidence interval does not cross threshold (CIlower > threshold),
then profile is associated with sensitivity / resistance

Z score = (OS - criterion) / SEo
P value = 2 * (1 - (cumulative distribution function(abs(Z))))
-------------------

Drug ranking:
-------------------
For each pair of drugs A & B:
Standard error(A - B) = sqrt(OS variance(A) + OS variance(B))
Z = (Overall(A) - Overall(B)) / Standard error(A - B)
-------------------

- Match molecule & state (i.e., Condition)
- For matching facts, run prevalent hypothesis computation
- Throw out molecules that don't meet criterion for prevalent hypothesis
- For remaining molecules, run profile matching Z score, discard drugs that don't meet criterion
- For remaining drugs, compute & sort by P value

=end

require 'gsl'

class CalcSet
  include DataMapper::Resource

  belongs_to :hypothesis, :key => true
  property :sign, Integer, :key => true
  property :evidence_score, Float, :default => 0.0
  property :corrected_evidence_score, Float
  property :score_percentage, Float
  property :corrected_score_percentage, Float
  property :variance, Float
  property :standard_error, Float
  property :confidence_interval, Float
  property :confidence_interval_upper, Float
  property :confidence_interval_lower, Float
  property :weight, Float
  property :weight_times_sp, Float

  def fill(total_score, corrected_total_score)
    self.score_percentage = self.evidence_score / total_score
    self.corrected_evidence_score = self.evidence_score + (1.96**2 / 2.0)
    #corrected_total_score = total_score + 1.96**2
    self.corrected_score_percentage = self.corrected_evidence_score / corrected_total_score
    self.variance = (self.corrected_score_percentage.abs * (1.0 - self.corrected_score_percentage.abs)) / corrected_total_score
    self.standard_error = Math.sqrt(self.variance.abs)
    self.confidence_interval = 1.96*self.standard_error
    self.confidence_interval_upper = self.corrected_score_percentage + self.confidence_interval
    self.confidence_interval_lower = self.corrected_score_percentage - self.confidence_interval
    self.weight = 1.0 / self.variance.abs
    self.weight_times_sp = self.weight * self.score_percentage
  end

  def z(threshold)
    (self.score_percentage - threshold) / self.standard_error
  end

  def p(z)
    2.0 * (1.0 - GSL::Cdf::gaussian_P(z.abs))
  end

end

class Hypothesis

  include DataMapper::Resource
  ## variable name convention: _p = plus, _m = minus, _n = null, _t = total

  property :id, Serial

  belongs_to :drug
  has n, :factoids
  has 3, :calc_sets
  property :relation, Enum[:efficacy, :toxicity, :synergism, :progression]
  property :condition, String, :index => true, :length => 255
  property :total_score, Float, :default => 0.0
  property :corrected_total_score, Float
  property :prevalent, Integer
  property :prevalent_percentage, Float

  after :create do
    (-1..1).each {|s| CalcSet.create(:sign => s, :hypothesis => self)}
  end

  def self.summarize_evidence_initial(relation)
    puts "Precalculating summary of evidence for #{relation}"
    hypotheses = Set.new

    Drug.all.each do |drug|
      factoids = Factoid.all(:drug_name => drug.name, :relation => relation)
      factoids.each do |f|
        h = f.hypothesis
        hypotheses << h
        model_score = 6.0 * 2.0**(f.evidence_type - 1.0)
        size_score = [1.0, f.cases/10.0].max
        evidence_score = model_score * size_score
        h.calc_sets[f.h+1].evidence_score += evidence_score
        h.total_score += evidence_score.abs
      end
    end

    puts "#{hypotheses.length} hypotheses"
    counter = 0
    hypotheses.each do |h|
      counter += 1
      print '.'
      STDOUT.flush
      if counter >= 100
        puts ''
        counter = 0
      end
      h.corrected_total_score = h.total_score + 1.96**2
      h.calc_sets.each {|c| c.fill(h.total_score, h.corrected_total_score)}
      h.prevalent = h.calc_sets.find_index {|c| c.corrected_score_percentage > 0.5} # 0.5 is minimum reasonable threshold, all must add to 1
      h.prevalent_percentage = h.calc_sets[h.prevalent].corrected_score_percentage if h.prevalent
      h.save!
    end
    puts ''
  end

  def self.find_prevalent(drugs, relation, threshold)
    return Hypothesis.all(:drug => drugs, :relation => relation,
                          :prevalent.not => nil, :prevalent_percentage.gt => threshold)
  end
  
  def self.rank_drugs(test_results, drugs, relation, threshold)
    threshold = threshold.to_f
    drug_hyp_hash = {}
    results = {}
    unpacked_results = Hypothesis.unpack_results(test_results)
#    unpacked_results.each {|k,v| puts "#{k} = #{v}"}
    h_considered = Hypothesis.all(:prevalent.not => nil, :drug => drugs,
                                  :condition => unpacked_results.keys, :relation => relation)
    h_considered.each do |h|
      if drug_hyp_hash[h.drug.name].nil?
        drug_hyp_hash[h.drug.name] = {:hypotheses => [h], :overall_score => 0.0, :sum_weights => 0.0, :sum_weight_times_sp => 0.0,
                                 :os_standard_error => 0.0, :os_variance => 0.0, :os_ci_upper => 0.0, :os_ci_lower => 0.0, :z => 0.0}
      else
          drug_hyp_hash[h.drug.name][:hypotheses] << h
      end
    end

    drug_hyp_hash.each do |drug_name, drug_info|
      drug_info[:hypotheses].each do |h|
        rc = unpacked_results[h.condition] * (h.prevalent - 1) # rc is concordance
        drug_info[:condition] = h.condition
        if rc
          drug_info[:sum_weight_times_sp] += h.calc_sets[h.prevalent].weight_times_sp * rc
          drug_info[:sum_weights] += h.calc_sets[h.prevalent].weight
        end
      end
      if drug_info[:sum_weights] != 0.0
        drug_info[:overall_score] = drug_info[:sum_weight_times_sp] / drug_info[:sum_weights]
        drug_info[:os_variance] = 1.0 / drug_info[:sum_weights]
        drug_info[:os_standard_error] = Math.sqrt(drug_info[:os_variance])
        os_confidence_interval = 1.96 * drug_info[:os_standard_error]
        drug_info[:os_ci_upper] = drug_info[:overall_score] + os_confidence_interval
        drug_info[:os_ci_lower] = drug_info[:overall_score] - os_confidence_interval
        drug_info[:z] = (drug_info[:overall_score].abs - threshold) / drug_info[:os_standard_error]
        drug_info[:p] = 2.0 * (1.0 - GSL::Cdf::gaussian_P(drug_info[:z].abs))
#        puts "drug=#{drug_name}, condition=#{drug_info[:condition]}, os=#{drug_info[:overall_score]}, osv=#{drug_info[:os_variance]}, z=#{drug_info[:z]}, p=#{drug_info[:p]}"
        results[drug_name] = drug_info
      end
    end
    return results.sort_by {|r| -(r[1][:overall_score])}
  end

  def prevalence_string
    if self.prevalent
      case self.relation
        when :efficacy then ["resistance", "no relationship", "sensitivity"]
        when :toxicity then ["toxicity decreased", "toxicity unchanged", "toxicity increased"]
        when :synergism then ["antagonism", "no synergism", "synergism"]
        when :progression then ["progression favored", "", ""]
      end[self.prevalent]
    end
  end

  protected
  def self.unpack_results(results)
    rhash = {}
    results.split(',').collect {|r| rhash[r.slice(0..-2)] =
        case r.slice(-1..-1); when 'p' then 1; when 'm' then -1; else 0; end}
    return rhash
  end

  

end
