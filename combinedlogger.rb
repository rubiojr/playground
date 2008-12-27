module Rack
  # Rack::CombinedLogger forwards every request to an +app+ given, and
  # logs a line in the Apache combined log format to the +logger+, or
  # rack.errors by default.
  class CombinedLogger 
    def initialize(app, logger=nil)
      @app = app
      @logger = logger
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      @env = env
      @logger ||= self
      @time = Time.now
      @status, @header, @body = @app.call(env)
      [@status, @header, self]
    end

    def close
      @body.close if @body.respond_to? :close
    end

    # By default, log to rack.errors.
    def <<(str)
      @env["rack.errors"].write(str)
      @env["rack.errors"].flush
    end

    def each
      length = 0
      @body.each { |part|
        length += part.size
        yield part
      }

      @now = Time.now

      # Combined Log Format: http://httpd.apache.org/docs/2.0/logs.html#combined
      # lilith.local - - [07/Aug/2006 23:58:02] "GET / HTTP/1.1" 500 - "http://referer" "User-Agent Foo"
      #             %{%s - %s [%s] "%s %s%s %s" %d %s "%s" "%s"\n} %
      @logger << %{%s - %s [%s] "%s %s%s %s" %d %s "%s" "%s"\n} %
        [
         @env['HTTP_X_FORWARDED_FOR'] || @env["REMOTE_ADDR"] || "-",
         @env["REMOTE_USER"] || "-",
         @now.strftime("%d/%b/%Y %H:%M:%S"),
         @env["REQUEST_METHOD"],
         @env["PATH_INFO"],
         @env["QUERY_STRING"].empty? ? "" : "?"+@env["QUERY_STRING"],
         @env["HTTP_VERSION"],
         @status.to_s[0..3],
         (length.zero? ? "-" : length.to_s),
         @env["HTTP_REFERER"],
         @env["HTTP_USER_AGENT"]
        ]
    end
  end
end
