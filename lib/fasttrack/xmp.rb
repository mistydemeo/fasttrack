# -*- coding: UTF-8 -*-
require 'fasttrack/namespaces'

require 'exempi'
require 'ffi'

module Fasttrack
  class XMP
    attr_accessor :xmp_ptr
    include Enumerable

    # Creates a new XMP object.
    # If a pointer to an XMP chunk is provided, it will be used;
    # otherwise, a new empty XMP chunk will be created.
    # @param [FFI::Pointer, nil] xmp_ptr XMP pointer to use, or nil
    def initialize xmp_ptr=nil
      if xmp_ptr and xmp_ptr.is_a? FFI::Pointer
        @xmp_ptr = xmp_ptr
      else
        @xmp_ptr = Exempi.xmp_new_empty
      end

      @iterator = nil
      @iterator_opts = nil
    end

    # This ensures that the clone is created with a new XMP pointer.
    def initialize_copy orig
      super
      @xmp_ptr = Exempi.xmp_copy @xmp_ptr
    end

    # Return an object from the global namespace.
    # @example Gets the value of the 'tiff:Make' property
    #   xmp.get :tiff, 'tiff:Make' #=> 'Sony'
    #   # you can also leave off the namespace prefix
    #   xmp.get :tiff, 'Make' #=> 'Sony'
    #   # You can use the namespace URI string too
    #   xmp.get 'http://ns.adobe.com/tiff/1.0/', 'Make' #=> 'Sony'
    # @param [String, Symbol] namespace namespace URI to use. If a
    #   symbol is provided, Fasttrack will look up the URI from a set of
    #   common recognized namespaces.
    # @param [String] prop property to look up.
    # @return [String, nil] the value of the requested property, or nil
    #   if not found.
    def get namespace, prop
      if namespace.is_a? Symbol
        namespace = Fasttrack::NAMESPACES[namespace]
      end

      prop_str = Exempi.xmp_string_new
      success = Exempi.xmp_get_property @xmp_ptr, namespace, prop, prop_str, nil
      if success
        result = Exempi.xmp_string_cstr prop_str

        result
      else
        result = nil
      end

      Exempi.xmp_string_free prop_str
      prop_str = nil

      result
    end

    alias_method :get_property, :get

    # Modifies an existing XMP property or creates a new property with
    # the specified value.
    # @example Sets the 'tiff:Make' property to 'Sony'
    #   xmp.set :tiff, 'tiff:Make', 'Sony' #=> 'Sony'
    # @param [String, Symbol] namespace namespace to use. If a symbol is
    #   provided, Fasttrack will look up from a set of common recognized
    #   namespaces.
    # @param [String] prop property to set.
    # @param [String] value value to set.
    # @return [String] the new value
    # @raise [Exempi::ExempiError] if Exempi reports that it failed
    def set namespace, prop, value
      if namespace.is_a? Symbol
        namespace = Fasttrack::NAMESPACES[namespace]
      end

      success = Exempi.xmp_set_property @xmp_ptr, namespace, prop, value, nil
      if success
        value
      else
        Fasttrack.handle_exempi_failure
      end
    end

    alias_method :set_property, :set

    # Fetches an XMP property given a string containing the namespace
    # prefix and the property name, e.g. "tiff:Make".
    # @example Returns the value of 'tiff:Make'
    #   xmp['tiff:Make'] #=> 'Sony'
    # @param [String] query query
    # @return [String, nil] the property's value, or nil if not found
    def [] query
      if query =~ /.+:.+/
        ns_prefix, property = query.scan(/(.+):(.+)/).flatten
      end

      ns_uri = Fasttrack::NAMESPACES[ns_prefix.downcase.to_sym]

      get_property ns_uri, property
    end

    # Sets an XMP property given a string containing the namespace
    # prefix and the property name, e.g. "tiff:Make".
    # @example Sets the value of 'tiff:Make' to 'Sony'
    #   xmp['tiff:Make'] = 'Sony' #=> 'Sony'
    # @param [String] property property
    # @param [String] value value to set
    # @return [String] the new value
    def []= property, value
      if property =~ /.+:.+/
        ns_prefix, property = property.scan(/(.+):(.+)/).flatten
      end

      ns_uri = Fasttrack::NAMESPACES[ns_prefix.downcase.to_sym]

      set_property ns_uri, property, value
    end

    # Deletes a given XMP property. If the property exists returns the
    # deleted property, otherwise returns nil.
    # @param (see #get_property)
    # @return [String, nil] the value of the deleted property, or nil if
    #   not found.
    def delete namespace, prop
      deleted_prop = get_property namespace, prop
      Exempi.xmp_delete_property @xmp_ptr, namespace, prop

      deleted_prop
    end

    alias_method :delete_property, :delete

    # Returns a list of namespace URIs in use in the specified XMP data.
    # @return [Array<String>] an array of URI strings
    def namespaces
      map {|ns,_,_,_| ns}.uniq!
    end

    # Serializes the XMP object to an XML string.
    # @return [String]
    def to_s
      xmp_str = Exempi.xmp_string_new
      Exempi.xmp_serialize @xmp_ptr, xmp_str, 0, 0
      string = Exempi.xmp_string_cstr xmp_str
      Exempi.xmp_string_free xmp_str

      string
    end

    # Defined to ensure that irb and other environments which depend on
    # #inspect get something sane, rather than the output of #to_s.
    # @return [String]
    def inspect
      ivars = instance_variables.map {|var| "#{var}=#{instance_variable_get var}"}
      "#<#{self.class}:#{object_id} #{ivars * ", "}>"
    end

    def each &block
      return to_enum unless block_given?

      iterate_for do |returned|
        block.call(returned)
      end
    end

    # Iterates over all properties, with the iteration rules guided
    # by the specified options. Options should be specified in an array.
    # @param [Array<Symbol>] opts array of one or more options
    # @option opts :properties Iterate the property tree of a TXMPMeta
    #   object.
    # @option opts :aliases Iterate the global namespace table.
    # @option opts :just_children Just do the immediate children of the
    #   root, default is subtree.
    # @option opts :just_leaf_nodes Just do the leaf nodes, default is
    #   all nodes in the subtree.
    # @option opts :just_leaf_name Return just the leaf part of the
    #   path, default is the full path.
    # @option opts :include_aliases Include aliases, default is just
    #   actual properties.
    # @option opts :omit_qualifiers Omit all qualifiers.
    # @return [Enumerator] if no block is given
    def each_with_options opts, &block
      return enum_for(:each_with_options, opts) unless block_given?

      options = opts.map {|o| ("XMP_ITER_"+o.to_s.delete("_")).to_sym}
      # filter out invalid options
      options.keep_if {|o| Exempi::XMP_ITER_OPTIONS.find o}

      iterate_for({:options => options}) do |returned|
        block.call(returned)
      end
    end

    # Iterates over all properties in a specified namespace.
    # The namespace parameter can be the URI of the namespace to use,
    # or a symbol representing the namespace prefix, e.g. :exif.
    # The recognized namespace prefixes are based on the constants in
    # Exempi::Namespaces, and are generated at runtime in
    # Fasttrack::NAMESPACES.
    # @param [String, Symbol] ns namespace to iterate over
    # @param [Array<Symbol>] opts a set of options to restrict the
    #   iteration; see #each_with_options for supported options
    # @return [Enumerator] if no block is given
    def each_in_namespace ns, opts=[], &block
      return enum_for(:each_with_namespace, ns) unless block_given?

      opts = {:namespace => ns}
      iterate_for(opts) do |returned|
        block.call(returned)
      end
    end

    def rewind
      @iterator = new_iterator
    end

    private

    # Creates a new iterator based on the options specified in the
    # @iterator_opts ivar, or an options hash if specified.
    # The options hash can specify the following:
    # :namespace => Limits the iteration to a specific namespace URI
    # :options => Options for the iteration; must be an array composed
    #   of one or more symbols specified in the Exempi::XmpIterOptions 
    #   enum.
    # @param [Hash] params hash containing the options for the new
    #   iterator.
    # @return [FFI::Pointer] pointer to the new iterator
    def new_iterator params=@iterator_opts
      ns   = params[:namespace]
      # property support is currently disabled
      prop = nil
      opts = params[:options]
      Exempi.xmp_iterator_new @xmp_ptr, ns, prop, opts
    end

    # This method is the plumbing which is used by the various
    # Enumerable mixin methods.
    # @param (see #new_iterator)
    # @yieldparam [String] uri the uri for the property
    # @yieldparam [String] name the property's name
    # @yieldparam [String] value the property's value
    # @yieldparam [Hash] options additional metadata about the property
    def iterate_for opts={}
      # Select the namespace; lookup symbol if appropriate, otherwise
      # use string or nil
      if opts[:namespace].is_a? Symbol
        ns = Fasttrack::NAMESPACES[opts[:namespace]]
      else
        ns = opts[:namespace]
      end

      # record iterator options; these are necessary to call subsequent
      # iterator functions
      @iterator_opts = {
        :namespace     => ns,
        # note that :property is currently unimplemented in Fasttrack
        :property      => opts[:property],
        :options       => opts[:options] || []
      }

      @iterator = new_iterator

      returned_ns         = Exempi.xmp_string_new
      returned_prop_path  = Exempi.xmp_string_new
      returned_prop_value = Exempi.xmp_string_new
      returned_prop_opts  = FFI::MemoryPointer.new :uint32

      # keep iterating until xmp_iterator_next() returns false, which
      # indicates it has finished traversing all the properties
      while Exempi.xmp_iterator_next(@iterator, returned_ns, returned_prop_path, returned_prop_value, nil)
        ary = [returned_ns, returned_prop_path, returned_prop_value].map do |xmp_str|
          Exempi.xmp_string_cstr xmp_str
        end

        ary << Exempi.parse_bitmask(returned_prop_opts.read_uint32,
          Exempi::XMP_PROPS_BITS)

        yield ary
      end
    end
  end
end