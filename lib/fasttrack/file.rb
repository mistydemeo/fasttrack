# -*- coding: UTF-8 -*- 
require 'fasttrack/xmp'

require 'exempi'
require 'ffi'
require 'pathname'

module Fasttrack
  class File
    attr_reader :xmp, :path, :file_ptr

    # Instantiates a new Fasttrack::File object, which is a representation of
    # a file on disk and its associated XMP metadata.
    # To create a new file on disk you should use Fasttrack::XMP#to_s instead.
    # @param [String] the path to the file on disk; must exist
    # @param [String] file mode; accepted values are "r" (read-only; default); "w" and "rw" (read-write)
    def initialize path, mode="r"
      @path = Pathname.new(path).expand_path
      raise ArgumentError, "#{@path} does not exist" unless @path.exist?
      @file_ptr = Exempi.xmp_files_new
      @read_mode = mode
      open @read_mode
    end

    # Checks to see whether XMP can be written to the current file.
    # If no XMP is specified, the file's associated XMP is used.
    # 
    # @param [FFI::Pointer, Fasttrack::XMP] The XMP to check; can be a Fasttrack::XMP object or a pointer to a C XMP object
    # @return [true,false]
    def can_put_xmp? xmp=@xmp
      if xmp.is_a? Fasttrack::XMP
        xmp = xmp.xmp_ptr
      end

      raise TypeError, "#{xmp} is not a pointer" unless xmp.is_a? FFI::Pointer

      Exempi.xmp_files_can_put_xmp @file_ptr, xmp
    end

    # Replaces the file's currently associated XMP object. The new XMP will not
    # be written to disk until #save! or #close! is called.
    # @param [Fasttrack::XMP] The XMP object to copy. Must be a Fasttrack::XMP object.
    # @return [Fasttrack::XMP] The copied object.
    def xmp= new_xmp
      if not new_xmp.is_a? Fasttrack::XMP
        raise TypeError, "#{new_xmp.class} is not a Fasttrack::XMP"
      end
      if not can_put_xmp? new_xmp
        message = "Unable to write XMP"
        message << "; file opened read-only" if @read_mode == "r"
        raise message
      end

      @xmp = new_xmp.dup
      Exempi.xmp_files_put_xmp @file_ptr, @xmp.xmp_ptr
    end

    # Save changes to a file.
    # Exempi only saves changes when a file is closed; this method
    # closes and then reopens the file so it can continue to be used.
    # This always uses Exempi's "safe close", which writes into a
    # temporary file and swap in case of unexpected termination.
    # @return [true, false] true if successful
    def save!
      raise "Unable to write XMP; file opened read-only" if @read_mode == "r"

      raise "file is closed" unless @open
      # Make sure we let Exempi know there's new XMP to write
      Exempi.xmp_files_put_xmp @file_ptr, @xmp.xmp_ptr
      close!
      open @read_mode
    end

    # Closes the current file and frees its memory.
    # While this will not save changes made to the current
    # XMP object, it still has the potential to make changes to
    # the file being closed.
    # @return [true, false] true if successful
    def close!
      raise "file is already closed" unless @open

      @open = !Exempi.xmp_files_close(@file_ptr, :XMP_CLOSE_SAFEUPDATE)
      if @open # did not successfully close
        Fasttrack.handle_exempi_failure
        false
      else
        true
      end
    end

    private

    # This method is considered plumbing and should not be directly called
    # by users of this class.
    #
    # @param [String] file mode
    def open mode=nil
      case mode
      when 'r'
        open_option = :XMP_OPEN_READ
      when 'w', 'rw'
        open_option = :XMP_OPEN_FORUPDATE
      else
        open_option = :XMP_OPEN_NOOPTION
      end

      @open = Exempi.xmp_files_open @file_ptr, @path.to_s, open_option

      if not @open
        Fasttrack.handle_exempi_failure
      else
        @xmp = get_xmp
      end

      @open
    end

    # Fetches XMP data from the file.
    # This is automatically done when a file is opened.
    # @return [Fasttrack::XMP] A new Fasttrack::XMP object
    def get_xmp
      Fasttrack::XMP.new Exempi.xmp_files_get_new_xmp @file_ptr
    end

  end
end