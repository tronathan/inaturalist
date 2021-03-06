class ProjectObservationRule < Rule
  OPERAND_OPERATORS_CLASSES = {
    "observed_in_place?" => "Place",
    "in_taxon?" => "Taxon",
    "has_observation_field?" => "ObservationField"
  }
  OPERAND_OPERATORS = OPERAND_OPERATORS_CLASSES.keys
  
  before_save :clear_operand
  validate :operand_present

  def operand_present
    if OPERAND_OPERATORS.include?(operator)
      if operand.blank? || !operand.is_a?(Object.const_get(OPERAND_OPERATORS_CLASSES[operator]))
        errors[:base] << "Must select a " + 
          OPERAND_OPERATORS_CLASSES[operator].underscore.humanize.downcase + 
          " for that rule."
      end
    end
  end
  
  def clear_operand
    return true if OPERAND_OPERATORS.include?(operator)
    self.operand = nil
    true
  end
  
  def terms
    if operator == "observed_in_place?" && operand
      "must be observed in #{send(:operand).display_name}"
    elsif operator == "has_observation_field?" && operand
      "must have observation field '#{operand.name}' filled out"
    else
      super
    end
  end
end
