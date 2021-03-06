require 'riakpb'
require 'set'

module Riakpb
  # Parent class of all object types supported by ripple. {Riakpb::RObject} represents
  # the data and metadata stored in a bucket/key pair in the Riakpb database.
  class Content
    include Util::Translation
    include Util::MessageCode

    # @return [Key] the key in which this Content is stored.
    attr_accessor   :key

    # @return [String] the data stored in Riakpb at this object's key.  Varies in format by content-type.
    attr_accessor   :value
    alias_attribute :data, :value

    # @return [String] the MIME content type of the object
    attr_accessor   :content_type

    # @return [String] the charset of the object
    attr_accessor   :charset

    # @return [String] the content encoding of the object
    attr_accessor   :content_encoding

    # @return [String] the vtag of the object
    attr_accessor   :vtag

    # @return [Set<Link>] an Set of {Riakpb::Link} objects for relationships between this object and other resources
    attr_accessor   :links

    # @return [Time] the Last-Modified header from the most recent HTTP response, useful for caching and reloading
    attr_accessor   :last_mod
    alias_attribute :last_modified, :last_mod

    # @return [Time] the Last-Modified header from the most recent HTTP response, useful for caching and reloading
    attr_accessor   :last_mod_usecs
    alias_attribute :last_modified_usecs, :last_mod_usecs

    # @return [Hash] a hash of any user-supplied metadata, consisting of a key/value pair
    attr_accessor   :usermeta
    alias_attribute :meta, :usermeta

    attr_accessor   :options

   # Create a new riak_content object manually
    # @param [Riakpb::Key] key Key instance that owns this Content (really, you should use the Key to get this)
    # @param [Hash] contents Any contents to initialize this instance with
    # @see Key#content
    # @see Content#load
    def initialize(key, options={})
      @key              = key unless key.nil?
      @links            = Hash.new{|k,v| k[v] = []}
      @usermeta         = {}
      @options          = options

      self.last_mod     = Time.now

      yield self if block_given?
    end

    def [](attribute)
      instance_variable_get "@#{attribute}"
    end

    # Load information for the content from the response object, Riakpb::RpbContent.
    # @param [RpbContent/Hash] contents an RpbContent object or a Hash.
    # @return [Content] self
    def load(content)
      case content
      when Riakpb::RpbContent, Hash, Riakpb::Content
        last_mod          = content[:last_mod]
        last_mod_usecs    = content[:last_mod_usecs]

        if not (last_mod.blank? or last_mod_usecs.blank?)
          self.last_mod = Time.at "#{last_mod}.#{last_mod_usecs}".to_f
        end

        @content_type     = content[:content_type]     unless content[:content_type].blank?
        @charset          = content[:charset]          unless content[:charset].blank?
        @content_encoding = content[:content_encoding] unless content[:content_encoding].blank?
        @vtag             = content[:vtag]             unless content[:vtag].blank?
        self.links        = content[:links]            unless content[:links].blank?
        self.usermeta     = content[:usermeta]         unless content[:usermeta].blank?

        unless content[:value].blank?
          case @content_type
          when /json/
            @value = ActiveSupport::JSON.decode(content[:value]) 
          when /octet/
            @value = Marshal.load(content[:value])
          else
            @value = content[:value]
          end
        end
      else raise ArgumentError, t("riak_content_type")
      end

      return(self)
    end

    def merge(content)
      @links.merge(
        self.links  = content[:links]
      ) unless content[:links].blank?

      @usermega.merge(
        self.usermeta = content[:usermeta]
      ) unless content[:usermeta].blank?

      @content_type     = content[:content_type]     unless content[:content_type].blank?
      @value            = content[:value]
      @charset          = content[:charset]          unless content[:charset].blank?
      @content_encoding = content[:content_encoding] unless content[:content_encoding].blank?
      @vtag             = content[:vtag]             unless content[:vtag].blank?
      @last_mod         = content[:last_mod]
      @last_mod_usecs   = content[:last_mod_usecs]

      return(self)
    end

    # Save the Content instance in riak.
    # @option options [Fixnum] w (write quorum) how many replicas to write to before returning a successful response
    # @option options [Fixnum] dw how many replicas to commit to durable storage before returning a successful response
    # @option options [true/false] return_body whether or not to have riak return the key, once saved.  default = true
    def save(options={})
      begin
        self.save!(options)
      rescue FailedRequest
        return(false)
      end
      return(true)
    end

    # Save the Content instance in riak.  Raise/do not rescue on failure.
    # @option options [Fixnum] w (write quorum) how many replicas to write to before returning a successful response
    # @option options [Fixnum] dw how many replicas to commit to durable storage before returning a successful response
    # @option options [true/false] return_body whether or not to have riak return the key, once saved.  default = true
    def save!(options={})
      options[:content] = self
      options           = @options.merge(options)

      return(true) if @key.save(options)
      return(false) # Create and raise Error message for this?  Extend "Failed Request"?
    end


    # Internalizes a link to a Key, which will be saved on next call to... uh, save
    # @param [Hash] tags name of the tag, pointing to a Key instance, or an array ["bucket", "key"]
    # @return [Hash] links that this Content points to
    def link_key(tags)
      raise TypeError.new t('invalid_tag') unless tags.is_a?(Hash) or tags.is_a?(Array)

      tags.each do |tag, link|
        case link
        when Array
          newlink = Riakpb::RpbLink.new
          newlink[:bucket]            = link[0]
          newlink[:key]               = link[1]
          raise ArgumentError.new t('invalid_tag') if link[0].nil? or link[1].nil?

          @links[tag.to_s]  <<  newlink

        when Riakpb::Key
          @links[tag.to_s] << link

        else
          raise TypeError.new t('invalid_tag')
        end
      end # tags.each do |tag, link|
    end
    alias :link :link_key

    # Set the links to other Key in riak.
    # @param [RpbGetResp, RpbPutResp] contains the tag/bucket/key of a given link
    # @return [Set] links that this Content points to
    def links=(pb_links)
      @links.clear

      case pb_links
      when Hash
        pb_links.each do |k, v|
          raise TypeError.new unless k.is_a?(String)

          if v.is_a?(Array)
            @links[k] += v
          else
            @links[k] << v
          end
        end

      when Array, Protobuf::Field::FieldArray
        pb_links.each do |pb_link|
          @links[pb_link.tag] << @key.get_linked(pb_link.bucket, pb_link.key, {:safely => true})
        end
      else
        raise TypeError.new
      end

      return(@links)
    end


    def last_mod=(time_mod)
      @last_mod = Time.at time_mod
    end

    # @return [Riakpb::RpbContent] An instance of a RpbContent, suitable for protobuf exchange
    def to_pb
      rpb_content                   = Riakpb::RpbContent.new
      rpb_links                     = []

      @links.each do |tag, links|
        links.each do |link|
          case link
          when Riakpb::RpbLink
            rpb_links   <<  hlink
          when Riakpb::Key
            pb_link     =   link.to_pb_link
            pb_link.tag =   tag
            rpb_links   <<  pb_link
          end
        end
      end

      usermeta                      = []
      @usermeta.each do |key,value|
        pb_pair         =   Riakpb::RpbPair.new
        pb_pair[:key]   =   key
        pb_pair[:value] =   value
        usermeta        <<  pb_pair
      end

      catch(:redo) do
        case @content_type
        when /octet/
          rpb_content.value = Marshal.dump(@value) unless @value.blank?
        when /json/
          rpb_content.value = ActiveSupport::JSON.encode(@value) unless @value.blank?
        when "", nil
          @content_type     = "application/json"
          redo
        else
          rpb_content.value = @value.to_s unless @value.blank?
        end
      end

      rpb_content.content_type      = @content_type     unless @content_type.blank?
      rpb_content.charset           = @charset          unless @charset.blank? # || @charset.empty?
      rpb_content.content_encoding  = @content_encoding unless @content_encoding.blank? # || @content_encoding.empty?
      rpb_content.links             = rpb_links         unless rpb_links.blank?
      rpb_content.usermeta          = usermeta          unless usermeta.blank?

      return(rpb_content)
    end

    # @return [String] A representation suitable for IRB and debugging output
    def inspect
      "#<#Riakpb::Content " + [
          (@value.nil?)             ? nil : "value=#{@value.inspect}",
          (@content_type.nil?)      ? nil : "content_type=#{@content_type.inspect}",
          (@charset.nil?)           ? nil : "charset=#{@charset.inspect}",
          (@content_encoding.nil?)  ? nil : "content_encoding=#{@content_encoding.inspect}",
          (@vtag.nil?)              ? nil : "vtag=#{@vtag.inspect}",
          (@links.nil?)             ? nil : "links=#{@_links.inspect}",
          (@last_mod.nil?)          ? nil : "last_mod=#{last_mod.inspect}",
          (@last_mod_usecs.nil?)    ? nil : "last_mod_usecs=#{last_mod_usecs.inspect}",
          (@usermeta.nil?)          ? nil : "usermeta=#{@usermeta.inspect}"

        ].compact.join(", ") + ">"
    end

    private

  end # class Content
end # module Riakpb
