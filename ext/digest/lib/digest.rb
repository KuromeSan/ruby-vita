require 'digest.so'
autoload :Base64, 'base64'

module Digest
  def self.const_missing(name)
    case name
    when :SHA256, :SHA384, :SHA512
      lib = 'digest/sha2.so'
    else
      lib = File.join('digest', name.to_s.downcase)
    end

    begin
      require lib
    rescue LoadError => e
      raise LoadError, "library not found for class Digest::#{name} -- #{lib}", caller(1)
    end
    unless Digest.const_defined?(name)
      raise NameError, "uninitialized constant Digest::#{name}", caller(1)
    end
    Digest.const_get(name)
  end

  class ::Digest::Class
    # creates a digest object and reads a given file, _name_.
    #
    #  p Digest::SHA256.file("X11R6.8.2-src.tar.bz2").hexdigest
    #  # => "f02e3c85572dc9ad7cb77c2a638e3be24cc1b5bea9fdbb0b0299c9668475c534"
    def self.file(name)
      new.file(name)
    end

    # Returns the base64 encoded hash value of a given _string_.  The
    # return value is properly padded with '=' and contains no line
    # feeds.
    def self.base64digest(str, *args)
      Base64.strict_encode64(digest(str, *args))
    end
  end

  module Instance
    # updates the digest with the contents of a given file _name_ and
    # returns self.
    def file(name)
      File.open(name, "rb") {|f|
        buf = ""
        while f.read(16384, buf)
          update buf
        end
      }
      self
    end

    # If none is given, returns the resulting hash value of the digest
    # in a base64 encoded form, keeping the digest's state.
    #
    # If a _string_ is given, returns the hash value for the given
    # _string_ in a base64 encoded form, resetting the digest to the
    # initial state before and after the process.
    #
    # In either case, the return value is properly padded with '=' and
    # contains no line feeds.
    def base64digest(str = nil)
      Base64.strict_encode64(str ? digest(str) : digest)
    end

    # Returns the resulting hash value and resets the digest to the
    # initial state.
    def base64digest!
      Base64.strict_encode64(digest!)
    end
  end
end

def Digest(name)
  Digest.const_get(name)
end
