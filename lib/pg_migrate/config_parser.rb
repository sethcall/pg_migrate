require 'yaml'

module PgMigrate

  class ConfigParser

    def self.rails(path, environment)

      config = {}

      rails_config = YAML.load_file(path)

      if !rails_config.has_key?(environment)
        raise "no environment #{environment} found in rails config file: #{path}"
      end

      rails_config = rails_config[environment]

      # populate from rails YAML to PG

      # required parameters 1st
      if !rails_config.has_key?("database")
        raise "no database key found in #{path} with environment #{environment}"
      end

      config[:dbname] = rails_config["database"]

      if rails_config.has_key?("host")
        config[:host] = rails_config["host"]
      end

      if rails_config.has_key?("port")
        config[:port] = rails_config["port"]
      end

      if rails_config.has_key?("username")
        config[:user] = rails_config["username"]
      end

      if rails_config.has_key?("password")
        config[:password] = rails_config["password"]
      end

      return config

    end

  end
end