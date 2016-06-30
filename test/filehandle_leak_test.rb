require 'fasttrack'
require 'open3'

describe Fasttrack::File do
  before do
    @test_file = File.join(__FILE__,'..','data','test.rtf')
  end

  it 'should not leak filehandles' do
    out, _ = Open3.capture2e("lsof")
    assert(!out.include?('test.rtf'))
    assert_raises Exempi::ExempiError do
      Fasttrack::File.new(@test_file)
    end
    out, _ = Open3.capture2e("lsof")
    assert(!out.include?('test.rtf'))
  end
end
