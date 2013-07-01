module Importer
  def get_url_from_redirect(uri)
    res = Net::HTTP.get_response(uri)
    location = %w(301 302).include?(res.code) ? (res.get_fields('Location') || []) : []
    location.first
  end


  def get_rss_attributes(recallurl)

        rss_url = "http://www.cpsc.gov/en/Newsroom/CPSC-RSS-Feed/Recalls-RSS/"
        rss_doc = Nokogiri::XML(open(rss_url)).remove_namespaces!

# Search the CPSC RSS feed to see if recall url exists,  if so grab Title, Description, and Thumbnail link
          mtch = rss_doc.search "[text()*='#{recallurl}']"
          mtch_url = mtch.first

            if mtch_url
              title = mtch_url.parent.xpath("title").text
              rssdescription = mtch_url.parent.xpath("description").text 
              image = "http://www.cpsc.gov" + mtch_url.parent.xpath('./group/content')[0]['url'] # must add domain prefix
            end  
 
       return title, rssdescription, image
  end

end