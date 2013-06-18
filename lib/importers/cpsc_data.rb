require 'rexml/document'
require 'nokogiri'
require 'open-uri'

module CpscData
  extend Importer

  def self.import_from_xml_feed(url)
    begin

       cpsc_api = REXML::Document.new(Net::HTTP.get(URI(url)))
      
        rss_url = "http://www.cpsc.gov/en/Newsroom/CPSC-RSS-Feed/Recalls-RSS/"
        rss_doc = Nokogiri::XML(open(rss_url)).remove_namespaces!

       
       cpsc_api.elements.each('message/results/result') do |element|   
        recall_number = element.attributes['recallNo']

        Recall.transaction do
          recall = Recall.where(organization: 'CPSC', recall_number: recall_number).first_or_initialize
          recall.y2k = element.attributes['y2k']
          recall.recalled_on = Date.parse(element.attributes['recDate']) rescue nil
          recall_url = element.attributes['recallURL'].strip
          recall.url = get_cpsc_url(recall_number, URI(recall_url)) || recall_url
          descrip = element.attributes['prname']
          
# Search the CPSC RSS feed to see if recall url exists,  if so grab Title, Description, and Thumbnail link
          mtch = rss_doc.search "[text()*='#{recall.url}']"
          mtch_url = mtch.first

           if defined? mtch_url
              addtitle = mtch_url.parent.xpath("title").text
              adddescription = mtch_url.parent.xpath("description").text 
              addimage = "http://www.cpsc.gov" + mtch_url.parent.xpath('./group/content')[0]['url'] # must add domain prefix
               if defined? adddescription
                 descrip = adddescription
              end
           end  
           


          attributes = {
              manufacturer: element.attributes['manufacturer'],
              product_type: element.attributes['type'],
              description: descrip,
              upc: element.attributes['UPC'],
              hazard: element.attributes['hazard'],
              country: element.attributes['country_mfg'],
              title: addtitle,
              image: addimage       
          }

          Recall::CPSC_DETAIL_TYPES.each do |detail_type|
            detail_value = attributes[detail_type.underscore.to_sym]
            next if detail_value.blank?

            if recall.new_record?
              recall.recall_details << RecallDetail.new(detail_type: detail_type,
                                                        detail_value: detail_value)
            else
              recall.recall_details.where(detail_type: detail_type,
                                          detail_value: StringSanitizer.sanitize(detail_value)).first_or_create!
            end
          end
          recall.save!
        end
      end
    rescue => e
      Rails.logger.error(e.message)
    end
  end

  def self.get_cpsc_url(recall_number, recall_url)
    cpsc_url = get_url_from_redirect(URI(recall_url))
    unless cpsc_url
      legacy_url = "http://www.cpsc.gov/cpscpub/prerel/prhtml#{recall_number[0..1]}/#{recall_number}.html"
      params = {query: legacy_url, OldURL: true, autodisplay: true }
      search_url = "http://cs.cpsc.gov/ConceptDemo/SearchCPSC.aspx?#{params.to_param}"
      cpsc_url = get_url_from_redirect(URI(search_url))
    end
    cpsc_url
  end
end
