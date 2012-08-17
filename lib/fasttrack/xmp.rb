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
    # @param [FFI::Pointer, nil] The XMP chunk to use, or nil
    def initialize xmp_ptr=nil
      if xmp_ptr and xmp_ptr.is_a? FFI::Pointer
        @xmp_ptr = xmp_ptr
      else
        @xmp_ptr = Exempi.xmp_new_empty
      end

      @iterator = nil
      @iterator_namespace = nil
    end

    # This ensures that the clone is created with a new XMP pointer
    def initialize_copy orig
      super
      @xmp_ptr = Exempi.xmp_copy @xmp_ptr
    end

    # Return an object from the global namespace
    # @param[String, Symbol] The namespace to use. If a symbol is provided, Fasttrack will look up from a set of common recognized namespaces.
    # @param [String] The property to look up.
    # @return [String, nil] The value of the requested property, or nil if not found.
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

    # Fetches an XMP property given a string containing the namespace
    # prefix and the property name, e.g. "tiff:Make"
    # @param[String] The query
    # @return[String, nil] The property's value, or nil if not found
    def [] query
      if query =~ /.+:.+/
        ns_prefix, property = query.scan(/(.+):(.+)/).flatten
      end

      ns_uri = Fasttrack::NAMESPACES[ns_prefix.downcase.to_sym]

      get_property ns_uri, property
    end

    # Deletes a given XMP property. If the property exists returns the deleted
    # property, otherwise returns nil
    # @param (see #get_property)
    # @return [String, nil] The value of the deleted property, or nil if not found.
    def delete namespace, prop
      deleted_prop = get_property namespace, prop
      Exempi.xmp_delete_property @xmp_ptr, namespace, prop

      deleted_prop
    end

    alias_method :delete_property, :delete

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
    # #inspect get something sane, rather than the output of #to_s
    # @return [String]
    def inspect
      ivars = instance_variables.map {|var| "#{var}=#{instance_variable_get var}"}
      "#<#{self.class}:#{object_id} #{ivars * ", "}>"
    end
  end
end