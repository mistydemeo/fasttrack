require 'minitest/autorun'
require 'fasttrack'

describe Fasttrack do
  it "should be able to handle Exempi errors" do
    lambda do
      Exempi.xmp_files_open_new "invalid_file", nil
      Fasttrack.handle_exempi_failure
    end.must_raise Exempi::ExempiError
  end
end