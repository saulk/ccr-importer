require 'nokogiri'
STDERR.puts "indir = #{ARGV[0]}   outdir = #{ARGV[1]}"
Dir.glob("#{ARGV[0]}/*.xml") do |item|
   # do work on real items
   STDERR.puts "Processing #{item}"
   doc = Nokogiri::XML(File.open(item))
   doc.root.attribute_nodes.each do |node|
     STDERR.puts node
   end
#   doc.root.remove_attribute('urn:astm-org:CCR')
#   doc.remove_namespaces!
   File.open(item.sub(ARGV[0], ARGV[1]),"w") do |out|
     out.write(doc)
   end
end
