require 'test/unit'
require 'tmpdir'
require 'tempfile'
require File.expand_path('../envutil', __FILE__)

class TestArgf < Test::Unit::TestCase
  def setup
    @t1 = Tempfile.new("argf-foo")
    @t1.binmode
    @t1.puts "1"
    @t1.puts "2"
    @t1.close
    @t2 = Tempfile.new("argf-bar")
    @t2.binmode
    @t2.puts "3"
    @t2.puts "4"
    @t2.close
    @t3 = Tempfile.new("argf-baz")
    @t3.binmode
    @t3.puts "5"
    @t3.puts "6"
    @t3.close
    @tmps = [@t1, @t2, @t3]
  end

  def teardown
    @tmps.each {|t|
      bak = t.path + ".bak"
      File.unlink bak if File.file? bak
      t.close(true)
    }
  end

  def make_tempfile
    t = Tempfile.new("argf-qux")
    t.puts "foo"
    t.puts "bar"
    t.puts "baz"
    t.close
    @tmps << t
    t
  end

  def ruby(*args)
    args = ['-e', '$>.write($<.read)'] if args.empty?
    ruby = EnvUtil.rubybin
    f = IO.popen(([ruby] + args).map {|s| "'#{s}'"}.join(' '), 'r+')
    yield(f)
  ensure
    f.close unless !f || f.closed?
  end

  def no_safe_rename
    /cygwin|mswin|mingw|bccwin/ =~ RUBY_PLATFORM
  end

  def test_argf
    src = <<-SRC
      a = ARGF
      p [a.gets.chomp, a.lineno] #=> ["1", 1]
      p [a.gets.chomp, a.lineno] #=> ["2", 2]
      a.rewind
      p [a.gets.chomp, a.lineno] #=> ["1", 1]
      p [a.gets.chomp, a.lineno] #=> ["2", 2]
      p [a.gets.chomp, a.lineno] #=> ["3", 3]
      p [a.gets.chomp, a.lineno] #=> ["4", 4]
      p [a.gets.chomp, a.lineno] #=> ["5", 5]
      a.rewind
      p [a.gets.chomp, a.lineno] #=> ["5", 5]
      p [a.gets.chomp, a.lineno] #=> ["6", 6]
    SRC
    expected = src.scan(/\#=> *(.+)/).flatten
    ruby('-e', src, @t1.path, @t2.path, @t3.path) do |f|
      f.each_with_index do |a, i|
        assert_equal(expected.shift, a.chomp, "[ruby-dev:34445]: line #{i}")
      end

      assert_equal([], expected, "[ruby-dev:34445]: remained")

      # is this test OK? [ruby-dev:34445]
    end
  end

  def test_lineno
    src = <<-SRC
      a = ARGF
      a.gets; p $.  #=> 1
      a.gets; p $.  #=> 2
      a.gets; p $.  #=> 3
      a.rewind; p $.  #=> 3
      a.gets; p $.  #=> 3
      a.gets; p $.  #=> 4
      a.rewind; p $.  #=> 4
      a.gets; p $.  #=> 3
      a.lineno = 1000; p $.  #=> 1000
      a.gets; p $.  #=> 1001
      a.gets; p $.  #=> 1002
      $. = 2000
      a.gets; p $.  #=> 2001
      a.gets; p $.  #=> 2001
    SRC
    expected = src.scan(/\#=> *(.+)/).join(",")
    ruby('-e', src, @t1.path, @t2.path, @t3.path) do |f|
      assert_equal(expected, f.read.chomp.gsub("\n", ","))
    end
  end

  def test_tell
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      begin
        ARGF.binmode
        loop do
          p ARGF.tell
          p ARGF.gets
        end
      rescue ArgumentError
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      [0, 2, 4, 2, 4, 2, 4].map {|i| i.to_s }.
      zip((1..6).map {|i| '"' + i.to_s + '\n"' } + ["nil"]).flatten.
      each do |x|
        assert_equal(x, a.shift)
      end
      assert_equal('end', a.shift)
    end
  end

  def test_seek
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.seek(4)
      p ARGF.gets #=> "3"
      ARGF.seek(0, IO::SEEK_END)
      p ARGF.gets #=> "5"
      ARGF.seek(4)
      p ARGF.gets #=> nil
      begin
        ARGF.seek(0)
      rescue
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      assert_equal('"3\n"', a.shift)
      assert_equal('"5\n"', a.shift)
      assert_equal('nil', a.shift)
      assert_equal('end', a.shift)
    end
  end

  def test_set_pos
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.pos = 4
      p ARGF.gets #=> "3"
      ARGF.pos = 4
      p ARGF.gets #=> "5"
      ARGF.pos = 4
      p ARGF.gets #=> nil
      begin
        ARGF.pos = 4
      rescue
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      assert_equal('"3\n"', a.shift)
      assert_equal('"5\n"', a.shift)
      assert_equal('nil', a.shift)
      assert_equal('end', a.shift)
    end
  end

  def test_rewind
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.pos = 4
      ARGF.rewind
      p ARGF.gets #=> "1"
      ARGF.pos = 4
      p ARGF.gets #=> "3"
      ARGF.pos = 4
      p ARGF.gets #=> "5"
      ARGF.pos = 4
      p ARGF.gets #=> nil
      begin
        ARGF.rewind
      rescue
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      assert_equal('"1\n"', a.shift)
      assert_equal('"3\n"', a.shift)
      assert_equal('"5\n"', a.shift)
      assert_equal('nil', a.shift)
      assert_equal('end', a.shift)
    end
  end

  def test_fileno
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      p ARGF.fileno
      ARGF.gets
      ARGF.gets
      p ARGF.fileno
      ARGF.gets
      ARGF.gets
      p ARGF.fileno
      ARGF.gets
      ARGF.gets
      p ARGF.fileno
      ARGF.gets
      begin
        ARGF.fileno
      rescue
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      fd1, fd2, fd3, fd4, tag = a
      assert_match(/^\d+$/, fd1)
      assert_match(/^\d+$/, fd2)
      assert_match(/^\d+$/, fd3)
      assert_match(/^\d+$/, fd4)
      assert_equal('end', tag)
    end
  end

  def test_to_io
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      8.times do
        p ARGF.to_io
        ARGF.gets
      end
    SRC
      a = f.read.split("\n")
      f11, f12, f13, f21, f22, f31, f32, f4 = a
      assert_equal(f11, f12)
      assert_equal(f11, f13)
      assert_equal(f21, f22)
      assert_equal(f31, f32)
      assert_match(/\(closed\)/, f4)
      f4.sub!(/ \(closed\)/, "")
      assert_equal(f31, f4)
    end
  end

  def test_eof
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      begin
        8.times do
          p ARGF.eof?
          ARGF.gets
        end
      rescue IOError
        puts "end"
      end
    SRC
      a = f.read.split("\n")
      (%w(false) + (%w(false true) * 3) + %w(end)).each do |x|
        assert_equal(x, a.shift)
      end
    end

    t1 = Tempfile.new("argf-foo")
    t1.binmode
    t1.puts "foo"
    t1.close
    t2 = Tempfile.new("argf-bar")
    t2.binmode
    t2.puts "bar"
    t2.close
    ruby('-e', 'STDERR.reopen(STDOUT); ARGF.gets; ARGF.skip; p ARGF.eof?', t1.path, t2.path) do |f|
      assert_equal(%w(false), f.read.split(/\n/))
    end
  end

  def test_read
    ruby('-e', "p ARGF.read(8)", @t1.path, @t2.path, @t3.path) do |f|
      assert_equal("\"1\\n2\\n3\\n4\\n\"\n", f.read)
    end
  end

  def test_read2
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = ""
      ARGF.read(8, s)
      p s
    SRC
      assert_equal("\"1\\n2\\n3\\n4\\n\"\n", f.read)
    end
  end

  def test_read3
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      nil while ARGF.gets
      p ARGF.read
      p ARGF.read(0, "")
    SRC
      assert_equal("nil\n\"\"\n", f.read)
    end
  end

  def test_getc
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = ""
      while c = ARGF.getc
        s << c
      end
      puts s
    SRC
      assert_equal("1\n2\n3\n4\n5\n6\n", f.read)
    end
  end

  def test_getbyte
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = []
      while c = ARGF.getbyte
        s << c
      end
      p s
    SRC
      assert_equal("[49, 10, 50, 10, 51, 10, 52, 10, 53, 10, 54, 10]\n", f.read)
    end
  end

  def test_readchar
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = ""
      begin
        while c = ARGF.readchar
          s << c
        end
      rescue EOFError
        puts s
      end
    SRC
      assert_equal("1\n2\n3\n4\n5\n6\n", f.read)
    end
  end

  def test_readbyte
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      begin
        s = []
        while c = ARGF.readbyte
          s << c
        end
      rescue EOFError
        p s
      end
    SRC
      assert_equal("[49, 10, 50, 10, 51, 10, 52, 10, 53, 10, 54, 10]\n", f.read)
    end
  end

  def test_each_line
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = []
      ARGF.each_line {|l| s << l }
      p s
    SRC
      assert_equal("[\"1\\n\", \"2\\n\", \"3\\n\", \"4\\n\", \"5\\n\", \"6\\n\"]\n", f.read)
    end
  end

  def test_each_byte
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = []
      ARGF.each_byte {|c| s << c }
      p s
    SRC
      assert_equal("[49, 10, 50, 10, 51, 10, 52, 10, 53, 10, 54, 10]\n", f.read)
    end
  end

  def test_each_char
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      s = ""
      ARGF.each_char {|c| s << c }
      puts s
    SRC
      assert_equal("1\n2\n3\n4\n5\n6\n", f.read)
    end
  end

  def test_filename
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      begin
        puts ARGF.filename.dump
      end while ARGF.gets
      puts ARGF.filename.dump
    SRC
      a = f.read.split("\n")
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
    end
  end

  def test_filename2
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.eof?
      begin
        puts $FILENAME.dump
      end while ARGF.gets
      puts $FILENAME.dump
    SRC
      a = f.read.split("\n")
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
    end
  end

  def test_file
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      begin
        puts ARGF.file.path.dump
      end while ARGF.gets
      puts ARGF.file.path.dump
    SRC
      a = f.read.split("\n")
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t1.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t2.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
      assert_equal(@t3.path.dump, a.shift)
    end
  end

  def test_binmode
    ruby('-e', "ARGF.binmode; STDOUT.binmode; puts ARGF.read", @t1.path, @t2.path, @t3.path) do |f|
      f.binmode
      assert_equal("1\n2\n3\n4\n5\n6\n", f.read)
    end
  end

  def test_skip
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.skip
      puts ARGF.gets
      ARGF.skip
      puts ARGF.read
    SRC
      assert_equal("1\n3\n4\n5\n6\n", f.read)
    end
  end

  def test_close
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      ARGF.close
      puts ARGF.read
    SRC
      assert_equal("3\n4\n5\n6\n", f.read)
    end
  end

  def test_closed
    ruby('-e', <<-SRC, @t1.path, @t2.path, @t3.path) do |f|
      3.times do
        p ARGF.closed?
        ARGF.gets
        ARGF.gets
      end
      p ARGF.closed?
      ARGF.gets
      p ARGF.closed?
    SRC
      assert_equal("false\nfalse\nfalse\nfalse\ntrue\n", f.read)
    end
  end
end
