require 'minitest/autorun'
require 'fasttrack'

require 'fileutils'
require 'tmpdir'

describe Fasttrack::File do
  before do
    @test_data  = File.join(__FILE__,"..","data","avchd.xmp")
    @test_image = File.join(__FILE__,"..","data","image.jpg")

    @tmpdir = Dir.mktmpdir
    Dir.chdir @tmpdir
  end

  it "should be able to create a new file object" do
    Fasttrack::File.new(@test_data).must_be_kind_of Fasttrack::File
  end

  it "should raise when created with a file that doesn't exist" do
    lambda do
      Fasttrack::File.new "no_file_here"
    end.must_raise Errno::ENOENT
  end

  it "should be able to report whether XMP can be written to a file" do
    # If the file is opened read-only the answer should be false
    file = Fasttrack::File.new @test_data, "r"
    refute file.can_put_xmp?

    # also test when file is opened for writing
    file = Fasttrack::File.new @test_image, "w"
    assert file.can_put_xmp?
  end

  it "should be able to save changes to a file" do
    file1 = Fasttrack::File.new @test_data
    FileUtils.copy File.expand_path(@test_image), "temp.jpg"
    file2 = Fasttrack::File.new "temp.jpg", "w"
    file2.xmp = file1.xmp
    assert file2.save!
    assert file2.close!
  end

  it "should be able to reopen a closed file" do
    FileUtils.copy File.expand_path(@test_image), "temp.jpg"
    file1 = Fasttrack::File.new "temp.jpg", "w"
    file1.close!
    file2 = Fasttrack::File.new @test_data
    file1.open
    file1.xmp = file2.xmp
    assert file1.save!
  end

  it "should raise when saving changes to a closed file" do
    lambda do
      file1 = Fasttrack::File.new @test_data
      file1.close!
      file2 = Fasttrack::File.new @test_image
      file1.xmp = file2.xmp      
    end.must_raise Fasttrack::WriteError
  end

  it "should raise when reopening an open file" do
    lambda do
      file1 = Fasttrack::File.new @test_data
      file1.open
    end.must_raise Fasttrack::OpenError
  end

  it "should be able to copy XMP file to file" do
    file1 = Fasttrack::File.new @test_data
    FileUtils.copy File.expand_path(@test_image), "temp.jpg"
    file2 = Fasttrack::File.new "temp.jpg", "w"

    file2_orig = file2.xmp
    file2.xmp = file1.xmp
    file2.save!
    file2.xmp.wont_be_same_as file2_orig
  end

  it "should be able to copy manually-created XMP into a file" do
    FileUtils.copy File.expand_path(@test_image), "temp.jpg"
    file = Fasttrack::File.new "temp.jpg", "w"

    new_xmp = Exempi.xmp_new_empty
    Exempi.xmp_set_property new_xmp, Fasttrack::NAMESPACES[:tiff],
      'tiff:Make', 'Sony', nil

    old_xmp = file.xmp
    file.xmp = new_xmp
    file.save!
    file.xmp.wont_be_same_as old_xmp
  end
  
  it "should raise when trying to write xmp into a read-only file" do
    file1 = Fasttrack::File.new @test_data
    file2 = Fasttrack::File.new @test_image

    lambda {file2.xmp = file1.xmp}.must_raise Fasttrack::WriteError
  end

  it "should raise when trying to copy non-XMP data into a file" do
    FileUtils.copy File.expand_path(@test_image), "temp.jpg"
    file = Fasttrack::File.new "temp.jpg", "w"

    lambda {file.xmp = 'xmp'}.must_raise TypeError
  end

  after do
    FileUtils.remove_entry_secure @tmpdir
  end
end