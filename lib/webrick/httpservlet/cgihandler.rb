#
# cgihandler.rb -- CGIHandler Class
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: cgihandler.rb,v 1.27 2003/03/21 19:56:01 gotoyuzo Exp $

require 'rbconfig'
require 'tempfile'
require 'webrick/config'
require 'webrick/httpservlet/abstract'

module WEBrick
  module HTTPServlet

    class CGIHandler < AbstractServlet
      Ruby = File::join(::Config::CONFIG['bindir'],
                        ::Config::CONFIG['ruby_install_name'])
      Ruby << ::Config::CONFIG['EXEEXT']
      CGIRunner = "\"#{Ruby}\" \"#{Config::LIBDIR}/httpservlet/cgi_runner.rb\""

      def initialize(server, name)
        super
        @script_filename = name
        @tempdir = server[:TempDir]
        @cgicmd = "#{CGIRunner} #{server[:CGIInterpreter]}"
      end

      def do_GET(req, res)
        data = nil
        status = -1

        cgi_in = IO::popen(@cgicmd, "wb")
        cgi_out = Tempfile.new("webrick.cgiout.", @tempdir)
        cgi_err = Tempfile.new("webrick.cgierr.", @tempdir)
        begin
          cgi_in.sync = true
          meta = req.meta_vars
          meta["SCRIPT_FILENAME"] = @script_filename
          meta["PATH"] = @config[:CGIPathEnv]
          if /mswin|bccwin|mingw/ =~ RUBY_PLATFORM
            meta["SystemRoot"] = ENV["SystemRoot"]
          end
          dump = Marshal.dump(meta)

          cgi_in.write("%8d" % cgi_out.path.size)
          cgi_in.write(cgi_out.path)
          cgi_in.write("%8d" % cgi_err.path.size)
          cgi_in.write(cgi_err.path)
          cgi_in.write("%8d" % dump.size)
          cgi_in.write(dump)

          if req.body and req.body.size > 0
            cgi_in.write(req.body)
          end
        ensure
          cgi_in.close
          status = $?.exitstatus
          sleep 0.1 if /mswin|bccwin|mingw/ =~ RUBY_PLATFORM
          data = cgi_out.read
          cgi_out.close(true)
          if errmsg = cgi_err.read
            if errmsg.size > 0
              @logger.error("CGIHandler: #{@script_filename}:\n" + errmsg)
            end
          end
          cgi_err.close(true)
        end

        if status != 0
          @logger.error("CGIHandler: #{@script_filename} exit with #{status}")
        end

        data = "" unless data
        raw_header, body = data.split(/^[\xd\xa]+/on, 2)
        raise HTTPStatus::InternalServerError,
          "Premature end of script headers: #{@script_filename}" if body.nil?

        begin
          header = HTTPUtils::parse_header(raw_header.lines.to_a)
          if /^(\d+)/ =~ header['status'][0]
            res.status = $1.to_i
            header.delete('status')
          end
          if header.has_key?('location')
            # RFC 3875 6.2.3, 6.2.4
            res.status = 302 unless (300...400) === res.status
          end
          if header.has_key?('set-cookie')
            header['set-cookie'].each{|k|
              res.cookies << Cookie.parse_set_cookie(k)
            }
            header.delete('set-cookie')
          end
          header.each{|key, val| res[key] = val.join(", ") }
        rescue => ex
          raise HTTPStatus::InternalServerError, ex.message
        end
        res.body = body
      end
      alias do_POST do_GET
    end

  end
end
