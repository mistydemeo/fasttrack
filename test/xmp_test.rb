require 'minitest/autorun'
require 'fasttrack'

describe Fasttrack::XMP do
  before do
    @test_data = File.join(__FILE__,"..","data","avchd.xmp")
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
end