module EventMachine
  class Ssh
    class ServerVersion
      include Log

      attr_reader :header
      attr_reader :version

      def initialize(connection)
        debug("#{self}.new(#{connection})")
        negotiate!(connection)
      end


      private

      def negotiate!(connection)
        @header = ''
        cb = connection.on(:data) do |data|
          log.debug("#{self.class}.on(:data, #{data.inspect})")
          data = StringIO.new(data)
          loop do
            @version = ""
            loop do
              begin
                b = data.read(1)
                raise Net::SSH::Disconnect, "connection closed by remote host" if b.nil?
              rescue EOFError
                raise Net::SSH::Disconnect, "connection closed by remote host"
              end
              @version << b
              break if b == "\n"
            end
            @header << @version
            break if @version.match(/^SSH-/)
          end

          if @version[-1] == "\n"
            @version.chomp!
            log.debug("server version: #{@version}")
            if !@version.match(/^SSH-(1\.99|2\.0)-/)
              connection.fire(:error, SshError.new("incompatible SSH version `#{@version}'"))
            else
              log.debug("local version: #{Net::SSH::Transport::ServerVersion::PROTO_VERSION}")
              connection.send_data("#{Net::SSH::Transport::ServerVersion::PROTO_VERSION}\r\n")
              cb.cancel
              connection.fire(:version_negotiated)
              connection.receive_data(data.read) unless data.eof?
              data.close
            end
          end # @header[-1] == "\n"
        end #  |data|
      end
    end # class::ServerVersion
  end # module::Ssh
end # module::EventMachine
