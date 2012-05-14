module HQMF2
  # Represents a data criteria specification
  class DataCriteria
  
    include HQMF2::Utilities
    
    attr_reader :property, :type, :status, :value, :effective_time, :section
  
    # Create a new instance based on the supplied HQMF entry
    # @param [Nokogiri::XML::Element] entry the parsed HQMF entry
    def initialize(entry)
      @entry = entry
      @status = attr_val('./*/cda:statusCode/@code')
      @effective_time = extract_effective_time
      @id_xpath = './cda:observationCriteria/cda:id/@extension'
      @code_list_xpath = './cda:observationCriteria/cda:code'
      @value_xpath = './cda:observationCriteria/cda:value'
      
      entry_type = attr_val('./*/cda:definition/*/cda:id/@extension')
      case entry_type
      when 'Problem', 'Problems'
        @type = :diagnosis
        @code_list_xpath = './cda:observationCriteria/cda:value'
        @section = 'conditions'
      when 'Encounter', 'Encounters'
        @type = :encounter
        @id_xpath = './cda:encounterCriteria/cda:id/@extension'
        @code_list_xpath = './cda:encounterCriteria/cda:code'
        @section = 'encounters'
      when 'LabResults', 'Results'
        @type = :result
        @value = extract_value
        @section = 'results'
      when 'Procedure', 'Procedures'
        @id_xpath = './cda:procedureCriteria/cda:id/@extension'
        @code_list_xpath = './cda:procedureCriteria/cda:code'
        @type = :procedure
        @section = 'procedures'
      when 'Medication', 'Medications'
        @type = :medication
        @id_xpath = './cda:substanceAdministrationCriteria/cda:id/@extension'
        @code_list_xpath = './cda:substanceAdministrationCriteria/cda:participant/cda:roleParticipant/cda:code'
        @section = 'medications'
      when 'RX'
        @type = :medication
        @id_xpath = './cda:supplyCriteria/cda:id/@extension'
        @code_list_xpath = './cda:supplyCriteria/cda:participant/cda:roleParticipant/cda:code'
        @section = 'medications'
      when 'Demographics'
        @type = :characteristic
        @property = property_for_demographic
        @value = extract_value
      when nil
        @type = :variable
        @value = extract_value
      else
        raise "Unknown data criteria template identifier [#{entry_type}]"
      end
    end
    
    def to_s
      props = {
        :property => property,
        :type => type,
        :status => status,
        :section => section
      }
      "DataCriteria#{props.to_s}"
    end
    
    # Get the identifier of the criteria, used elsewhere within the document for referencing
    # @return [String] the identifier of this data criteria
    def id
      attr_val(@id_xpath)
    end
    
    # Get the subset code (e.g. FIRST)
    # @return [String] the subset code
    def subset_code
      attr_val('./cda:subsetCode/@code')
    end
    
    # Get the title of the criteria, provides a human readable description
    # @return [String] the title of this data criteria
    def title
      @entry.at_xpath('./cda:localVariableName', HQMF2::Document::NAMESPACES).inner_text
    end
    
    # Get the code list OID of the criteria, used as an index to the code list database
    # @return [String] the code list identifier of this data criteria
    def code_list_id
      attr_val("#{@code_list_xpath}/@valueSet")
    end
    
    def inline_code_list
      codeSystemName = attr_val("#{@code_list_xpath}/@codeSystemName")
      codeValue = attr_val("#{@code_list_xpath}/@code")
      if codeSystemName && codeValue
        {codeSystemName => [codeValue]}
      else
        nil
      end
    end
    
    def to_json
      json = build_hash(self, [:title,:section,:subset_code,:code_list_id, :property, :type, :status])
      json[:value] = self.value.to_json if self.value
      json[:effective_time] = self.effective_time.to_json if self.effective_time
      json[:inline_code_list] = self.inline_code_list if self.inline_code_list
      {self.id.to_sym => json}
    end
    
    
    private
    
    def extract_effective_time
      effective_time_def = @entry.at_xpath('./*/cda:effectiveTime', HQMF2::Document::NAMESPACES)
      if effective_time_def
        EffectiveTime.new(effective_time_def)
      else
        nil
      end
    end
    
    def extract_value
      value = nil
      value_def = @entry.at_xpath(@value_xpath, HQMF2::Document::NAMESPACES)
      if value_def
        value_type_def = value_def.at_xpath('@xsi:type', HQMF2::Document::NAMESPACES)
        if value_type_def
          value_type = value_type_def.value
          case value_type
          when 'TS'
            value = Value.new(value_def)
          when 'IVL_PQ'
            value = Range.new(value_def)
          when 'CD'
            value = Coded.new(value_def)
          else
            raise "Unknown value type [#{value_type}]"
          end
        end
      end
      value
    end
    
    def property_for_demographic
      demographic_type = attr_val('./cda:observationCriteria/cda:code/@code')
      case demographic_type
      when '424144002'
        :age
      when '263495000'
        :gender
      when '102902016'
        :languages
      when '125680007'
        :maritalStatus
      when '103579009'
        :race
      else
        raise "Unknown demographic identifier [#{demographic_type}]"
      end
    end

  end
  
end