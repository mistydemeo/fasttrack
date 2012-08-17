require 'fasttrack/file'
require 'fasttrack/xmp'
require 'fasttrack/version'

require 'exempi/exceptions'

module Fasttrack
  # Checks for an Exempi error, and raises the appropriate exception.
  # Should only be used when an error has been detected from the boolean
  # output of one of Exempi's functions.
  def self.handle_exempi_failure
    error_code = Exempi.xmp_get_error
    message = Exempi.exception_for error_code
    raise Exempi::ExempiError.new(error_code), "Exempi failed with the code #{message}"
  end
end