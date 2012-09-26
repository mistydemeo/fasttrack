# Fasttrack

Fasttrack is a rubylike object-oriented interface around the [Exempi](http://libopenraw.freedesktop.org/wiki/Exempi) C library. It provides an easy way to read, write and modify embedded XMP metadata from arbitrary files.

## Installation

Add this line to your application's Gemfile:

    gem 'fasttrack'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fasttrack

## Usage

Opening a file:

```ruby
file = Fasttrack::File.new 'path' # add the 'w' parameter if you want to write
```

Editing the file's XMP:

```ruby
file.xmp.set :tiff, 'Make', 'Samsung'
# or, more prettily
file.xmp['tiff:Make'] = 'Samsung'
```

Iterate over the properties in a file:

```ruby
props = file.xmp.map {|p| p[1]}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

3-clause BSD, identical to the license used by Exempi and Adobe XMP Toolkit. For the license text, see LICENSE.