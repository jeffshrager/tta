class DrugMoleculeCalculator
  def self.compute(molecules)
    Rails.logger.debug "DrugMoleculeCalculator.compute() got molecules: #{molecules.to_json}"
  end
end