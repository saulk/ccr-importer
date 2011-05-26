
require 'nokogiri'
STDERR.puts "indir = #{ARGV[0]}   outdir = #{ARGV[1]} strip = #{ARGV[2]}"
if ARGV[2] == "strip"
  header = "<ContinuityOfCareRecord>"
else
  header = "<ContinuityOfCareRecord xmlns=\"urn:astm-org:CCR\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"urn:astm-org:CCR ADJE2369-2115.xsd\">"
end
    Dir.foreach(ARGV[0]) do |item|
       next if item == '.' ||  item == '..'
       fname = "#{ARGV[0]}/#{item}"
       # do work on real items
       STDERR.puts "Processing #{fname}"
       infp = File.open("#{fname}")
       outfp = File.open("#{ARGV[1]}/#{item}","w")
       IO.foreach(infp) do | line |
         pattern = /<ContinuityOfCareRecord.*/
         l = line
#         STDERR.puts pattern, line
         pattern =~ line
         data = Regexp.last_match
         if( data )
#           STDERR.puts "Found CCR record...substituting"
           outfp.puts header
         else
           outfp.puts l
#    STDERR.puts l
         end
     end
 end
