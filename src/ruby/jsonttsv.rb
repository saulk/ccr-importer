require 'json' 
def printX(value,fp)
      if(value)
          fp.print "Y"
     end
     fp.print "\t"
 end


  infile = ARGV[0]
   outfile = ARGV[1]

   if ARGV.size < 2
     STDERR.puts "usage:  jsontotsv <infile> <outfile>"
   end

  STDERR.puts "Opening #{outfile} for write"
  outfp = File.open(outfile,"w")
  STDERR.puts "Opening #{infile} for read"
  uncoded_terms = JSON.parse(File.open(infile).read)
  outfp.puts "Uncoded Term\tType\tSubtype\tCount\tCPT\tICD9\tSNOMEDCT\tLOINC\tRxNorm"
  uncoded_terms.each_pair do |key,value|
#     STDERR.puts "#{key} #{value} #{value["Codes"]}"
     outfp.print "#{key}\t#{value["Type"]}\t#{value["SubType"]}\t#{value["count"]}\t"
     printX(value["Codes"]["CPT"], outfp)
     printX(value["Codes"]["ICD9"], outfp)
     printX(value["Codes"]["SNOMEDCT"], outfp)
     printX(value["Codes"]["LOINC"], outfp)
     printX(value["Codes"]["Rxnorm"], outfp)
     outfp.print "\n"
  end
 outfp.close
