require 'minitest/autorun'
require 'fasttrack'

require 'nokogiri'
describe Fasttrack::XMP do
  before do
    @test_data = File.join(__FILE__,"..","data","avchd.xmp")
  end

  it "should be able to create an empty XMP packet" do
    xmp = Fasttrack::XMP.new
    xmp.namespaces.must_be_empty
  end

  it "should return the correct namespaces" do
    file = Fasttrack::File.new @test_data
    file.xmp.namespaces.must_equal [Fasttrack::NAMESPACES[:exif],
      Fasttrack::NAMESPACES[:tiff]]
  end

  it "should be able to fetch properties" do
    file = Fasttrack::File.new @test_data
    file.xmp['tiff:Make'].must_equal 'Sony'
    file.xmp.get(:tiff, 'tiff:Make').must_equal 'Sony'
    file.xmp.get(:tiff, 'Make').must_equal 'Sony'
    # Test looking up the namespaces from the table
    file.xmp.get(Fasttrack::NAMESPACES[:tiff],
      'Make').must_equal 'Sony'
    # Test using the literal URI string 
    file.xmp.get('http://ns.adobe.com/tiff/1.0/',
      'Make').must_equal 'Sony'
  end

  it "should be able to set properties" do
    file = Fasttrack::File.new @test_data
    file.xmp['tiff:Make'] = 'Samsung'
    file.xmp['tiff:Make'].must_equal 'Samsung'

    file.xmp.set :tiff, 'tiff:Make', 'Canon'
    file.xmp['tiff:Make'].must_equal 'Canon'

    file.xmp.set :tiff, 'Make', 'Olympus'
    file.xmp['tiff:Make'].must_equal 'Olympus'

    file.xmp.set Fasttrack::NAMESPACES[:tiff],
      'Make', 'Panasonic'
    file.xmp['tiff:Make'].must_equal 'Panasonic'

    file.xmp.set 'http://ns.adobe.com/tiff/1.0/', 'Make', 'Pentax'
    file.xmp['tiff:Make'].must_equal 'Pentax'
  end

  it "should be able to delete properties" do
    file = Fasttrack::File.new @test_data
    file.xmp.delete(:tiff, 'tiff:Make').must_equal 'Sony'
    file.xmp['tiff:Make'].must_be_nil
  end

  it "should return nil when deleting a property which doesn't exist" do
    xmp = Fasttrack::XMP.new
    xmp.delete(:exif, 'foo').must_be_nil
  end

  it "should not decrement the namespace count when deleting a nonextant property" do
    file = Fasttrack::File.new @test_data
    file.xmp.instance_variable_get(:@namespaces)["http://ns.adobe.com/exif/1.0/"].must_equal 7

    file.xmp.delete(:exif, 'foo')
    file.xmp.instance_variable_get(:@namespaces)["http://ns.adobe.com/exif/1.0/"].must_equal 7
  end

  it "should be able to iterate over properties" do
    file = Fasttrack::File.new @test_data
    file.xmp.each.must_be_kind_of Enumerator
    ary = file.xmp.each.to_a
    ary.first.must_be_kind_of Array
    ary.first.wont_be_empty
    # yeah, the first entry has empty properties
    # look at the hash later
    ary.first[0..-2].must_equal ['http://ns.adobe.com/exif/1.0/', '', '']

    # let's look at something with properties instead
    ary[1].must_include 'http://ns.adobe.com/exif/1.0/'
    ary[1].must_include 'exif:DateTimeOriginal'
    ary[1].must_include '2012-03-17T11:45:16-04:00'

    ary = file.xmp.map(&:last)
    ary.first.must_be_kind_of Hash
    ary.first.must_include :has_type
  end

  it "should be able to restrict iterations via namespace" do
    file = Fasttrack::File.new @test_data
    file.xmp.each_in_namespace(:exif).count.must_equal 8
  end

  it "should be able to rewind iterations" do
    file = Fasttrack::File.new @test_data
    enum = file.xmp.each
    enum.next
    enum.next
    ary = enum.next
    enum.rewind
    enum.next.wont_equal ary
  end

  it "should correctly track namespace usage" do
    file = Fasttrack::File.new @test_data
    file.xmp.namespaces.must_be_kind_of Array
    file.xmp.namespaces.count.must_equal 2
    ns = file.xmp.instance_variable_get :@namespaces
    ns.must_be_kind_of Hash
    ns['http://ns.adobe.com/exif/1.0/'].must_equal 7

    # is it properly decremented when we delete one of those properties?
    date = file.xmp.delete :exif, 'exif:DateTimeOriginal'
    ns['http://ns.adobe.com/exif/1.0/'].must_equal 6

    # how about incremented if we add one?
    file.xmp['exif:DateTimeOriginal'] = date
    ns['http://ns.adobe.com/exif/1.0/'].must_equal 7

    # is the hash udpated if we add a totally new namespace?
    file.xmp['pdf:Foo'] = 'bar'
    file.xmp.namespaces.must_include 'http://ns.adobe.com/pdf/1.3/'
  end

  it "should create copies with unique pointers" do
    file = Fasttrack::File.new @test_data
    xmp = file.xmp
    xmp2 = xmp.dup
    xmp.xmp_ptr.wont_equal xmp2.xmp_ptr
  end

  it "should be able to create XMP objects from XML strings" do
    xml_string = File.read File.expand_path(@test_data)
    xmp = Fasttrack::XMP.parse xml_string
    xmp.must_be_kind_of Fasttrack::XMP
    xmp['tiff:Make'].must_equal 'Sony'

    xmp_from_file = Fasttrack::File.new(@test_data).xmp
    xmp_from_file.must_equal xmp
  end

  it "should be able to serialize XMP to a string" do
    xmp = Fasttrack::XMP.new
    xmp['tiff:Make'] = 'Sony'
    xml = Nokogiri::XML.parse xmp.serialize
    xml.xpath("/x:xmpmeta/rdf:RDF/rdf:Description/tiff:Make",
      'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      'tiff' => 'http://ns.adobe.com/tiff/1.0/',
      'x' => 'adobe:ns:meta/').text.must_equal 'Sony'
  end

  it "should be able to create XMP objects from a file pointer" do
    file = Exempi.xmp_files_new
    Exempi.xmp_files_open file, File.expand_path(@test_data), :XMP_OPEN_READ

    xmp = Fasttrack::XMP.from_file_pointer file
    xmp['tiff:Make'].must_equal 'Sony'

    Exempi.xmp_files_free file
  end
end