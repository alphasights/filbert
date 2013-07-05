require 'yaml'
module Filbert
  class DbConfig
    def initialize(config_path, env)
      @config_path = config_path
      @env = env || ENV['RAILS_ENV'] || 'development'
    end

    def username
      config['username']
    end

    def database
      config['database']
    end

    def password
      config['password']
    end

    def config
      @config ||= YAML.load_file(@config_path)[@env]
    end
  end
end
