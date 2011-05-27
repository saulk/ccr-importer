require 'nokogiri'
    require 'json'
    require 'set'

$coded_values = {}
$uncoded = {}

module CCRscan
 class CCR

# initialize -- open the XML file and parse
    def initialize(ccrFilePath, summaryFilePath)
        @ccrFilePath = ccrFilePath
        @summaryFilePath = summaryFilePath
        STDERR.puts "initialize:  ccrFilePath = #{@ccrFilePath}"
        @doc = Nokogiri::XML(File.open(@ccrFilePath) ) 
#        @doc.remove_namespaces!()
        @summaryfp = File.open(@summaryFilePath,"w")
        @summary = {}
    end

#  process does all the heavy lifting
#    - adds any uncoded values discovered to the (global) uncoded_values_hash
#    - returns a hash with stats on coding
    def process(uncoded_values_hash)
         @uncoded = uncoded_values_hash

        uncoded_encounters = find_uncoded_encounters()
        uncoded_products = find_uncoded_products()
        uncoded_problems = find_uncoded_problems()
        uncoded_vital_results = find_uncoded_results("VitalSigns")
        uncoded_test_results = find_uncoded_results("Results")
        uncoded_alerts = find_uncoded_alerts()
#        perfect = uncoded_encounters.size > 0 && uncoded_products.size > 0 && uncoded_problems.size > 0 && uncoded_vital_results.size > 0 &&            uncoded_test_results.size > 0 && uncoded_alerts.size > 0
#        if perfect 
#                STDERR.puts "***PERFECT***"
#        end
#        STDERR.puts "e: #{uncoded_encounters.size} prod: #{uncoded_products.size}  prob: #{uncoded_problems.size} v: #{uncoded_vital_results.size} t: #{uncoded_test_results.size} a: #{uncoded_alerts.size}"
#        end
    @summaryfp.puts JSON.pretty_generate(@summary)
    @summaryfp.close

    end

#
## normalize_coding_system attempts to simplify analysis of the XML doc by normalizing the names of the coding systems
## Input is a single "Code" node in the tree, and the side effect is to edit the CodingSystem subnode.
##

    def normalize_coding_system(code)
        lookup = {
             "lnc" => "LOINC",
             "loinc" => "LOINC",
             "cpt" => "CPT",
             "cpt-4" => "CPT",
             "snomedct" => "SNOMEDCT",
             "snomed-ct" => "SNOMEDCT",
             "rxnorm" => "Rxnorm",
             "icd9-cm" => "ICD9",
             "icd9" => "ICD9"
        }
        codingsystem = lookup[code.xpath('./CodingSystem')[0].content.downcase]
        if(codingsystem)
                code.xpath('./CodingSystem')[0].content = codingsystem
        end
    end

   def add_uncoded_term(text, type, subtype, muvocabs)
      typeSubtype = "#{type}/#{subtype}"
      if !@uncoded[text]
         @uncoded[text] = {}
      end
      if !@uncoded[text][typeSubtype]    # if you find it you are done
          @uncoded[text][typeSubtype] =  {:ucount => 0,  :acount => 0, :MUCodes => {}, :alienCodes => {} }
      else
         return @uncoded[text][typeSubtype]     
      end
      element = @uncoded[text][typeSubtype]
      if !muvocabs.is_a?(Array)
        vocaba = [muvocabs]
      else
        vocaba = muvocabs 
      end
        # assume that each typeSubtype has a unique set of MU vocabularies
        vocaba.each do | vocab |
           element[:MUCodes][vocab] = "none"
        end

      return @uncoded[text][typeSubtype] 
   end

   def add_uncoded(text, type, subtype, muvocabs)
       STDERR.puts "add_uncoded text #{text}, type #{type}, subtype #{subtype}, muvocabs #{muvocabs}"
     element = add_uncoded_term(text,type, subtype, muvocabs)  #add it if it is missing
      element[:ucount] += 1
      return element
   end

   def add_alien_coded(text, type, subtype, muvocabs, alienCode, alienVocab)
      STDERR.puts "add_alien_coded text #{text}, type #{type}, subtype #{subtype}, muvocabs #{muvocabs}, alienCode #{alienCode}, alienVocab #{alienVocab}"
      element = add_uncoded_term(text,type,subtype, muvocabs)
      STDERR.puts "element = #{element[:alienCodes]}"
      if !element[:alienCodes][alienVocab]
           element[:alienCodes][alienVocab] =  [alienCode]
      else
           STDERR.puts "codes = #{element[:alienCodes][alienVocab]}"
           if !element[:alienCodes][alienVocab].to_set.member?(alienCode)
             element[:alienCodes][alienVocab].push(alienCode)
           end
      end
      STDERR.puts "element = #{element[:alienCodes]}"
      element[:acount] += 1
      return element
   end

def find_uncoded_results(type)
     uncoded_results = []
     alien_vocab = {}
     mu_vocab = {}
     mu_vocabs = ["SNOMEDCT","LOINC"]
    coded = 0
    mucoded = 0
     results = @doc.xpath("//" + type + "/Result")
     uncoded_results = []
#    STDERR.puts "#{type} Results: #{results.size}" 
    results.each do | result | 
         found_code = true
         codes = result.xpath("./Description/Code")
#        STDERR.puts "*Result Code: #{codes}"
        found_code = false
        if !codes.empty? 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" && mu_vocabs.to_set.member?(codetext)
                   found_mucode = true    
                   mu_vocab[ "#{codetext}" ] = true 
              else                                            # we found a value from another codeset
                 add_alien_coded(desctext, "type", "Result", mu_vocabs ,
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                 alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
           end
        else
           uncoded_results.push(result)
           add_uncoded(result.xpath("./Description/Text")[0].content, type, "Result", mu_vocabs);
        end
        test = result.xpath("./Test/Description")
        if !test.empty? 
        # STDERR.puts "*Test : #{test}"
         codes = test.xpath("./Code")
         if !codes.empty?
             found_code = true
             codes.each do | code | 
               normalize_coding_system(code)
             if code.xpath("./Value")[0].content != "0" && mu_vocabs.to_set.member?(codetext)
                   found_mucode = true    
                   mu_vocab[ "#{codetext}" ] = true 
              else                                            # we found a value from another codeset
                 add_alien_coded(desctext, type, "Result", mu_vocabs ,
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                 alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
            end
         else
          uncoded_results.push(result)
           add_uncoded(result.xpath("./Description/Text")[0].content, type, "Result", mu_vocabs);
         end
       end
      if found_code
        coded += 1
        if found_mucode
                mucoded += 1
        end
      end

    end
    @summary[type] = {:total => results.size, 
                           :coded => coded, 
                           :uncoded => results.size - coded,
                           :mucoded => mucoded,
                           :mu_vocab => mu_vocab.keys,
                           :alien_vocab => alien_vocab.keys }

    STDERR.puts JSON.pretty_generate(@summary[type])
    return uncoded_results
end


def find_uncoded_products()
     uncoded_products = []
     alien_vocab = {}
     mu_vocab = {}
     products = @doc.xpath("//Product")
#    STDERR.puts "Products: #{products.size}" 
    coded = 0
    mucoded = 0
    products.each do | product | 
        productName = product.xpath("./ProductName")[0]
        brandName = product.xpath("./BrandName")[0]
#        STDERR.puts "productName: #{productName.xpath("./Text")[0]}"
#        STDERR.puts "brandName: #{brandName.xpath("./Text")[0]}"
        codes = product.xpath("./ProductName/Code")
        found_code = false
        found_mucode = false;
        if codes.size > 0 
            found_code = true
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&   # we found an RXNorm value
                 code.xpath("./CodingSystem")[0].content == "Rxnorm"      
                 found_mucode = true 
                 mu_vocab["Rxnorm"] = true           
              else                                            # we found a value from another codeset
                 add_alien_coded(productName.xpath("./Text")[0].content, "Product", "ProductName",  "Rxnorm",
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
           end
        else
#        STDERR.puts "Uncoded productName: #{productName}"
           uncoded_products.push(productName)
           add_uncoded(productName.xpath("./Text")[0].content, "Product", "ProductName", "Rxnorm");
        end
#       STDERR.puts product.xpath("./BrandName/Text")
        codes = product.xpath("./BrandName/Code")
#       STDERR.puts "*Brand Code: #{codes}"
        if codes.size > 0 
              found_code = true
              codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&   # we found an RXNorm value
                 code.xpath("./CodingSystem")[0].content == "Rxnorm"  
                 found_mucode = true            
                 mu_vocab["Rxnorm"] = true  
              else                                            # we found a value from another codeset
                 add_alien_coded(brandName.xpath("./Text")[0].content, "Product", "BrandName",  "Rxnorm",
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                 alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
           end
        else
     STDERR.puts "Uncoded BrandName: #{productName}"
           uncoded_products.push(productName)
           add_uncoded(brandName.xpath("./Text")[0].content, "Product", "BrandName", "Rxnorm");
        end
      if found_code
        coded += 1
        if found_mucode
                mucoded += 1
        end
      end
     end
    @summary[:Products] = {:total => products.size, 
                           :coded => coded, 
                           :uncoded => products.size - coded,
                           :mucoded => mucoded,
                           :mu_vocab => mu_vocab.keys,
                           :alien_vocab => alien_vocab.keys }

    STDERR.puts JSON.pretty_generate(@summary[:Products])
    return uncoded_products

   end

def find_uncoded_problems()
     mu_vocabs = ["SNOMEDCT","ICD9","ICD10"]
     uncoded_problems = []
     alien_vocab = {}
     mu_vocab = {}
    coded = 0
    mucoded= 0
     uncoded_problems = []
     problems = @doc.xpath("//Problem")
     STDERR.puts "Problems: #{problems.size}" 
    problems.each do | problem | 
        found_code = false
        found_mucode = false;
        codes = problem.xpath("./Description/Code")
        desctext = problem.xpath("./Description/Text")[0].content
        if codes.size > 0 
              found_code = true
              codes.each do | code | 
              normalize_coding_system(code)
              codetext = code.xpath("./CodingSystem")[0].content
              if code.xpath("./Value")[0].content != "0" && mu_vocabs.to_set.member?(codetext)
                   found_mucode = true    
                   mu_vocab[ "#{codetext}" ] = true 
              else                                            # we found a value from another codeset
                 add_alien_coded(desctext, "Problem", "Problem", mu_vocabs ,
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                 alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
           end
        else
     STDERR.puts "Uncoded Problem: #{problem.xpath("./Description/Text")[0].content}"
           uncoded_problems.push(problem)
           add_uncoded(desctext, "Problem", "Problem", mu_vocabs);
        end
        if (found_code)
           coded = coded + 1
                if (found_mucode)
                        mucoded = mucoded+1
                end
        end
      end
    @summary[:Problems] = {:total => problems.size, 
                           :coded => coded, 
                           :uncoded => problems.size - coded,
                           :mucoded => mucoded,
                           :mu_vocab => mu_vocab.keys,
                           :alien_vocab => alien_vocab.keys }

    return uncoded_problems
end


 def find_uncoded_encounters()
     uncoded_encounters = []
     alien_vocab = {}
     mu_vocab = {}
    coded= 0
    mucoded = 0

     encounters = @doc.xpath("//Encounters/Encounter")
    STDERR.puts "Encounters: #{encounters.size}" 
     encounters.each do | encounter | 
        codes = encounter.xpath("./Description/Code")
        found_code = false
        found_mucode = false;
        if codes.size > 0 
            found_code = true
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&   # we found an CPT value
                 code.xpath("./CodingSystem")[0].content == "CPT"      
                 found_mucode = true 
                 mu_vocab["CPT"] = true           
              else                                            # we found a value from another codeset
                 add_alien_coded(encounter.xpath("./Description/Text")[0].content, "Encounter", "Encounter",  "CPT",
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end
           end
        else
#        STDERR.puts "Uncoded Encounter: #{encounter}"
           uncoded_encounters.push(encounter)
           add_uncoded(encounter.xpath("./Description/Text")[0].content, "Encounter", "Encounter",  "CPT");
        end
        if found_code
           coded = coded + 1
           if found_mu_code
              mucoded = mucoded + 1
           end
       end
      end
    @summary[:Encounters] = {:total => encounters.size, 
                           :coded => coded, 
                           :uncoded => encounters.size - coded,
                           :mucoded => mucoded,
                           :mu_vocab => mu_vocab.keys,
                           :alien_vocab => alien_vocab.keys }

    STDERR.puts JSON.pretty_generate(@summary[:Encounters])

    return uncoded_encounters
  end

def find_uncoded_alerts()
     uncoded_alerts = []
     alien_vocab = {}
     mu_vocab = {}
     coded= 0
     mucoded = 0
    alerts = @doc.xpath("//Alerts/Alert")
#    STDERR.puts "Alerts: #{alerts.size}" 
    alerts.each do | alert | 
#        STDERR.puts "*Alert : #{alert}"
        codes = alert.xpath("./Description/Code")
#        STDERR.puts "*Alert Code: #{codes}"
        found_code = false
        if codes.size > 0 
        found_code = true
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&
                 (code.xpath("./CodingSystem")[0].content == "Rxnorm")
                     found_mucode = true
              else                                            # we found a value from another codeset
                 add_alien_coded(alert.xpath("./Description/Text")[0].content, "Alert", "Alert",  ["Rxnorm"],
                         code.xpath("./Value")[0].content,
                         code.xpath("./CodingSystem")[0].content);
                 alien_vocab[code.xpath("./CodingSystem")[0].content] = true
              end

           end
        else
           uncoded_alerts.push(alert)
           add_uncoded(alert.xpath("./Description/Text")[0].content, "Alert", "Alert", [ "Rxnorm"]);
        end
        if found_code
           coded = coded + 1
           if found_mu_code
              mucoded = mucoded + 1
           end
       end
    end
    @summary[:Alerts] = {:total => alerts.size, 
                           :coded => coded, 
                           :uncoded => alerts.size - coded,
                           :mucoded => mucoded,
                           :mu_vocab => mu_vocab.keys,
                           :alien_vocab => alien_vocab.keys }

    return uncoded_alerts
end


end

end



# if launched as a standalone program, not loaded as a module
if __FILE__ == $0

   if ARGV.size < 2
     STDERR.puts "jruby xpath.rb <indir> <outdir> <outjsonfile> "
      exit
   end

   indir = ARGV[0]
   outfile = ARGV[1]

  STDERR.puts "indir = #{indir} outfile = #{outfile}"

  STDERR.puts "Opening #{outfile} for write"
  outputfp = File.open(outfile,"w")
 
     $coded_values = {}
  STDERR.puts "GORK"

  STDERR.puts $coded_values["N/A"]    # just testing that the read succeeded

  
   STDERR.puts "GORK indir = #{indir}"  
    Dir.glob("#{indir}/*.xml") do |item|
       next if item == '.' or item == '..'
       # do work on real items
       infilename = "#{item}"
       outfilename = "#{item}.json"
       STDERR.puts "Processing #{infilename}"
       STDERR.flush
       doc = CCRscan::CCR.new(infilename, outfilename) 
       doc.process($uncoded)
#       outfp = File.open("#{outdir}/#{item}","w")
#      outfp.close
     end 

  outputfp.puts JSON.pretty_generate($uncoded)

end
