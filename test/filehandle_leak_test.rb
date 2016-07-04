require 'fasttrack'
require 'open3'

describe Fasttrack::File do
  before do
    @test_file = File.join(__FILE__,'..','data','test.rtf')
  end

  it 'should not leak filehandles' do
    exempi_mock = MiniTest::Mock.new
    exempi_mock.expect(:xmp_files_open, false, [])
    exempi_mock.expect(:xmp_files_free, true, [])
    Exempi.stub(:xmp_files_open, false) { exempi_mock.xmp_files_open }
    Exempi.stub(:xmp_files_free, true) { exempi_mock.xmp_files_free }

    assert_raises Exempi::ExempiError do
      Fasttrack::File.new(@test_file)
    end
    exempi_mock.verify
  end
end
