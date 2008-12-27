module Rack
  # Rack::RequestLogger forwards every request to an +app+ given, and
  # logs a line in the Apache combined, common or combined_vhost log format
  # to the +logger+, or
  # rack.errors by default.
  #
  # Combined Log Format: http://httpd.apache.org/docs/2.0/logs.html#combined
  # Common Log Format: http://httpd.apache.org/docs/2.0/logs.html#common
  class RequestLogger
    
    def initialize(app, logger = nil)
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
      @body_length = 0
      @body.each { |part|
        @body_length += part.size
        yield part
      }
      @now = Time.now
      @logger << format_request
    end
  end

  class CombinedLogger < RequestLogger

    # format the request as a string
    def format_request
      %{%s - %s [%s] "%s %s%s %s" %d %s "%s" "%s"\n} %
        [
         @env['HTTP_X_FORWARDED_FOR'] || @env["REMOTE_ADDR"] || "-",
         @env["REMOTE_USER"] || "-",
         @now.strftime("%d/%b/%Y %H:%M:%S"),
         @env["REQUEST_METHOD"],
         @env["PATH_INFO"],
         @env["QUERY_STRING"].empty? ? "" : "?"+@env["QUERY_STRING"],
         @env["HTTP_VERSION"],
         @status.to_s[0..3],
         (@body_length.zero? ? "-" : @body_length.to_s),
         @env["HTTP_REFERER"],
         @env["HTTP_USER_AGENT"]
        ]
    end
  end

  class CombinedVhostLogger < RequestLogger
    
    # format the request as a string
    def format_request
      %{%s - %s [%s] "%s %s%s %s" %d %s "%s" "%s" [%s]\n} %
        [
         @env['HTTP_X_FORWARDED_FOR'] || @env["REMOTE_ADDR"] || "-",
         @env["REMOTE_USER"] || "-",
         @now.strftime("%d/%b/%Y %H:%M:%S"),
         @env["REQUEST_METHOD"],
         @env["PATH_INFO"],
         @env["QUERY_STRING"].empty? ? "" : "?"+@env["QUERY_STRING"],
         @env["HTTP_VERSION"],
         @status.to_s[0..3],
         (@body_length.zero? ? "-" : @body_length.to_s),
         @env["HTTP_REFERER"],
         @env["HTTP_USER_AGENT"],
         @env["HTTP_HOST"]
        ]
    end
  end

end
