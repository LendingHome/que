# frozen_string_literal: true

# Tools for logging from Que.

module Que
  module Utils
    module Logging
      attr_accessor :logger, :internal_logger
      attr_writer :log_formatter

      def log(event:, level: :info, **extra)
        data = _default_log_data
        data[:event] = Que.assert(Symbol, event)
        data.merge!(extra)

        if l = get_logger
          begin
            if output = log_formatter.call(data)
              l.send level, output
            end
          rescue => e
            msg =
              "Error raised from Que.log_formatter proc:" +
              " #{e.class}: #{e.message}\n#{e.backtrace}"

            l.error(msg)
          end
        end
      end

      # Logging method used specifically to instrument Que's internals. There's
      # usually not an internal logger set up, so this method is generally a no-
      # op unless the specs are running or someone turns on internal logging so
      # we can debug an issue.
      def internal_log(event, object = nil)
        if l = get_logger(internal: true)
          data = _default_log_data

          data[:internal_event] = Que.assert(Symbol, event)
          data[:object_id]      = object.object_id if object
          data[:t]              = Time.now.utc.iso8601(6)

          additional = Que.assert(Hash, yield)

          # Make sure that none of our log contents accidentally overwrite our
          # default data contents.
          expected_length = data.length + additional.length
          data.merge!(additional)
          Que.assert(expected_length == data.length) do
            "Bad internal logging keys in: #{additional.keys.inspect}"
          end

          l.info(JSON.dump(data))
        end
      end

      def get_logger(internal: false)
        if l = internal ? internal_logger : logger
          l.respond_to?(:call) ? l.call : l
        end
      end

      def log_formatter
        @log_formatter ||= JSON.method(:dump)
      end

      private

      def _default_log_data
        {
          lib:      :que,
          hostname: CURRENT_HOSTNAME,
          pid:      Process.pid,
          thread:   Thread.current.object_id,
        }
      end
    end
  end
end
