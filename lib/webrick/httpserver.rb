#
# httpserver.rb -- HTTPServer Class
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: httpserver.rb,v 1.63 2002/10/01 17:16:32 gotoyuzo Exp $

require 'webrick/server'
require 'webrick/httputils'
require 'webrick/httpstatus'
require 'webrick/httprequest'
require 'webrick/httpresponse'
require 'webrick/httpservlet'
require 'webrick/accesslog'

module WEBrick
  class HTTPServerError < ServerError; end

  class HTTPServer < ::WEBrick::GenericServer
    def initialize(config={}, default=Config::HTTP)
      super
      @http_version = HTTPVersion::convert(@config[:HTTPVersion])

      @mount_tab = MountTable.new
      if @config[:DocumentRoot]
        mount("/", HTTPServlet::FileHandler, @config[:DocumentRoot],
              @config[:DocumentRootOptions])
      end

      unless @config[:AccessLog]
        @config[:AccessLog] = [
          [ $stderr, AccessLog::COMMON_LOG_FORMAT ],
          [ $stderr, AccessLog::REFERER_LOG_FORMAT ]
        ]
      end

      @virtual_hosts = Array.new
    end

    def run(sock)
      while true
        res = HTTPResponse.new(@config)
        req = HTTPRequest.new(@config)
        server = self
        begin
          timeout = @config[:RequestTimeout]
          while timeout > 0
            break if IO.select([sock], nil, nil, 0.5)
            timeout = 0 if @status != :Running
            timeout -= 0.5
          end
          raise HTTPStatus::EOFError if timeout <= 0 || sock.eof?
          req.parse(sock)
          res.request_method = req.request_method
          res.request_uri = req.request_uri
          res.request_http_version = req.http_version
          res.keep_alive = req.keep_alive?
          server = lookup_server(req) || self
          if callback = server[:RequestCallback] || server[:RequestHandler]
            callback.call(req, res)
          end
          server.service(req, res)
        rescue HTTPStatus::EOFError, HTTPStatus::RequestTimeout => ex
          res.set_error(ex)
        rescue HTTPStatus::Error => ex
          @logger.error(ex.message)
          res.set_error(ex)
        rescue HTTPStatus::Status => ex
          res.status = ex.code
        rescue StandardError => ex
          @logger.error(ex)
          res.set_error(ex, true)
        ensure
          if req.request_line
            req.fixup()
            res.send_response(sock)
            server.access_log(@config, req, res)
          end
        end
        break if @http_version < "1.1"
        break unless req.keep_alive?
        break unless res.keep_alive?
      end
    end

    def service(req, res)
      if req.unparsed_uri == "*"
        if req.request_method == "OPTIONS"
          do_OPTIONS(req, res)
          raise HTTPStatus::OK
        end
        raise HTTPStatus::NotFound, "`#{req.unparsed_uri}' not found."
      end

      servlet, options, script_name, path_info = search_servlet(req.path)
      raise HTTPStatus::NotFound, "`#{req.path}' not found." unless servlet
      req.script_name = script_name
      req.path_info = path_info
      si = servlet.get_instance(self, *options)
      @logger.debug(format("%s is invoked.", si.class.name))
      si.service(req, res)
    end

    def do_OPTIONS(req, res)
      res["allow"] = "GET,HEAD,POST,OPTIONS"
    end

    def mount(dir, servlet, *options)
      @logger.debug(sprintf("%s is mounted on %s.", servlet.inspect, dir))
      @mount_tab[dir] = [ servlet, options ]
    end

    def mount_proc(dir, proc=nil, &block)
      proc ||= block
      raise HTTPServerError, "must pass a proc or block" unless proc
      mount(dir, HTTPServlet::ProcHandler.new(proc))
    end

    def unmount(dir)
      @logger.debug(sprintf("unmount %s.", dir))
      @mount_tab.delete(dir)
    end
    alias umount unmount

    def search_servlet(path)
      script_name, path_info = @mount_tab.scan(path)
      servlet, options = @mount_tab[script_name]
      if servlet
        [ servlet, options, script_name, path_info ]
      end
    end

    def virtual_host(server)
      @virtual_hosts << server
      @virtual_hosts = @virtual_hosts.sort_by{|s|
        num = 0
        num -= 4 if s[:BindAddress]
        num -= 2 if s[:Port]
        num -= 1 if s[:ServerName]
        num
      }
    end

    def lookup_server(req)
      @virtual_hosts.find{|s|
        (s[:BindAddress].nil? || req.addr[3] == s[:BindAddress]) &&
        (s[:Port].nil?        || req.port == s[:Port])           &&
        ((s[:ServerName].nil?  || req.host == s[:ServerName]) ||
         (!s[:ServerAlias].nil? && s[:ServerAlias].find{|h| h === req.host}))
      }
    end

    def access_log(config, req, res)
      param = AccessLog::setup_params(config, req, res)
      @config[:AccessLog].each{|logger, fmt|
        logger << AccessLog::format(fmt+"\n", param)
      }
    end

    class MountTable
      def initialize
        @tab = Hash.new
        compile
      end

      def [](dir)
        dir = normalize(dir)
        @tab[dir]
      end

      def []=(dir, val)
        dir = normalize(dir)
        @tab[dir] = val
        compile
        val
      end

      def delete(dir)
        dir = normalize(dir)
        res = @tab.delete(dir)
        compile
        res
      end

      def scan(path)
        @scanner =~ path
        [ $&, $' ]
      end

      private

      def compile
        k = @tab.keys
        k.sort!
        k.reverse!
        k.collect!{|path| Regexp.escape(path) }
        @scanner = Regexp.new("^(" + k.join("|") +")(?=/|$)")
      end

      def normalize(dir)
        ret = dir ? dir.dup : ""
        ret.sub!(%r|/+$|, "")
        ret
      end
    end
  end
end
