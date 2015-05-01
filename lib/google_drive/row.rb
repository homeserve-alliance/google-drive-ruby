# Author: Guy Boertje <https://github.com/guyboertje>
# The license of this source is "New BSD Licence"
require 'google_drive/util'

module GoogleDrive
  # Row behaves like a hash
  # converts a list feed entry (Nokogiri element) to a hash
  # unpacks the gsx namespaced elements [name, text]
  class Row < SimpleDelegator
    include Util
    # class factory methods

    def self.build(entry)
      row = new
      row.accept_entry entry
    end
    # V3 new entry xml

    # <entry xmlns="http://www.w3.org/2005/Atom" xmlns:gsx="http://schemas.google.com/spreadsheets/2006/extended">
    #   <gsx:hours>1</gsx:hours>
    #   <gsx:ipm>1</gsx:ipm>
    #   <gsx:items>60</gsx:items>
    #   <gsx:name>Elizabeth Bennet</gsx:name>
    # </entry>

    ENTRY_NSX = %Q|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:gsx="http://schemas.google.com/spreadsheets/2006/extended">|.freeze

    attr_reader :entry, :list, :etag
    # instance methods

    def dup
      row = self.class.new
      row.accept_row(self).with_list(@list)
    end

    def clean_dup
      row = self.class.new
      row.accept_keys(self).with_list(@list)
    end

    def initialize
      super Hash.new
    end

    def with_list(list)
      @list = list
      self
    end

    def store(key, value)
      k = key.to_s.gsub(/\p{^Alnum}/, '').downcase.to_sym
      __getobj__.store(k, value)
    end

    def update(hash)
      hash.each do |k,v|
        store(k,v)
      end
    end

    def insert
      @list.upload_insert(self)
    end

    def save
      @list.upload_update(self)
    end

    def edit_url
      raise ArgumentError.new("can't edit: entry not supplied") if @entry.nil?
      @entry.at_css("link[rel='edit']")['href']
    end

    def as_insert_xml
      xml = ENTRY_NSX.dup
      each do |k, v|
        tag = 'gsx:'.concat(k.to_s)
        xml.concat("<#{tag}>#{h(v)}</#{tag}>")
      end
      xml.concat('</entry>')
    end

    #V3 list feed entry
    # <entry gd:etag='"S0wCTlpIIip7ImA0X0QI"'>
    #   <id>https://spreadsheets.google.com/feeds/list/key/worksheetId/private/full/rowId</id>
    #   <updated>2006-11-17T18:23:45.173Z</updated>
    #   <category scheme="http://schemas.google.com/spreadsheets/2006"
    #     term="http://schemas.google.com/spreadsheets/2006#list"/>
    #   <title type="text">Bingley</title>
    #   <content type="text">Hours: 10, Items: 2, IPM: 0.0033</content>
    #   <link rel="self" type="application/atom+xml"
    #     href="https://spreadsheets.google.com/feeds/list/key/worksheetId/private/full/rowId"/>
    #   <link rel="edit" type="application/atom+xml"
    #     href="https://spreadsheets.google.com/feeds/list/key/worksheetId/private/full/rowId/version"/>
    #   <gsx:name>Bingley</gsx:name>
    #   <gsx:hours>20</gsx:hours>
    #   <gsx:items>4</gsx:items>
    #   <gsx:ipm>0.0033</gsx:ipm>
    # </entry>

    def as_update_xml
      raise ArgumentError.new("can't update: entry not supplied") if @entry.nil?
      each do |k, v|
        node = @entry.at_xpath("gsx:#{k}")
        node.content = h(v)
      end
      @entry.to_xml.sub!(%r{<entry.+>}, ENTRY_NSX.dup)
    end

    def accept_entry(entry)
      @entry = entry
      @etag = entry['gd:etag']
      entry.xpath('gsx:*').each do |field|
        store field.name.to_sym, field.text
      end
      self
    end

    def accept_row(row)
      row.each {|k,v| store(k, v)}
      self
    end

    def accept_keys(row)
      row.keys.each {|k| store(k, nil)}
      self
    end
  end
end
