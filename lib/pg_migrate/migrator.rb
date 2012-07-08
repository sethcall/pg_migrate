require 'pg'

module PgMigrate

  attr_accessor :conn, :connection_hash, :manifest_path, :manifest

  class Migrator


    def initialize(connection_hash)
      @connection_hash = connection_hash
      @manifest = nil


      #host
      #
      #    server hostname
      #hostaddr
      #
      #    server address (avoids hostname lookup, overrides host)
      #port
      #
      #    server port number
      #dbname
      #
      #    connecting database name
      #user
      #
      #    login user name
      #password
      #
      #    login password
      #connect_timeout
      #
      #    maximum time to wait for connection to succeed
      #options
      #
      #    backend options
      #tty
      #
      #    (ignored in newer versions of PostgreSQL)
      #sslmode
      #
      #    (disable|allow|prefer|require)
      #krbsrvname
      #
      #    kerberos service name
      #gsslib
      #
      #    GSS library to use for GSSAPI authentication
      #service
      #
      #    service name to use for additional parameters

    end

    def migrate(manifest_path)
      @manifest_path = manifest_path

      conn = PG::Connection.open(@connection_hash)

      process_manifest()
    end

    def process_manifest()
      load_manifest
      validate_manifest
    end

    def load_manifest(manifest_path)
      manifest = []
      # there should be a file called 'manifest' at this location
      manifest_lines = IO.readlines(manifest_path)
      manifest_lines.each do |line|
        # ignore comments
        if line.strip.empty? or line.strip.start_with?('#')
          # ignored!
        else
          manifest.push(line.strip)
        end
      end

      return manifest
    end
    
    def validate_manifest
      
    end

  end
end
