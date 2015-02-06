class DrugsController < ApplicationController
  def index
    @drugs = Drug.all(:order => :name.asc).collect {|d| d.name}
  end

  require 'ttd_utils'

  def load_ttd
    loader = TTDLoader.new
    loader.load("TargetedTherapyDatabase_TTD.txt")
      end

  def summarize_evidence    
    threshold = params[:threshold].to_f
    drugs     = Drug.all(:name => params[:drug].keys)
#    @relation  = params[:relation]
    @relation = "efficacy"
#    puts "t = #{threshold}, d = #{drugs.length}, d = #{drugs}, r = #{@relation}"
    @hypotheses = Hypothesis.find_prevalent(drugs, @relation, threshold)
#    @conditions = @hypotheses.collect {|h| h.condition }
#    puts "nhyps before = " + @hypotheses.length.to_s
    @conditions = @hypotheses.reject {|x| x.prevalent == 1}.collect {|h| h.condition }
#    puts "nhyps after = " + @hypotheses.length.to_s
    @threshold = threshold
    render :layout => false
  end

  def rank_drugs
    conditions = params[:test_results]
    threshold = params[:threshold].to_f
    drugs = Drug.all(:name => params[:drug].keys)
    #    relation = params[:relation]
    relation = :efficacy
    @ranking = Hypothesis.rank_drugs(conditions, drugs, relation, threshold)
    render :layout => false
  end

#  def drug_molecules_computed
#    molecules = params[:molecules]
#    results = DrugMoleculeCalculator.compute(molecules)
#    render :text=>"computing based on: <br> #{molecules.to_json}"
#  end
end
