# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'filbert/version'

Gem::Specification.new do |gem|
  gem.name          = "filbert"
  gem.version       = Filbert::VERSION
  gem.authors       = ["Tadas Tamosauskas"]
  gem.email         = ["tadas@pdfcv.com", "tech@alphasights.com"]
  gem.description   = "A utility to download backups from Heroku followers"
  gem.summary       = "Heroku followers' backups"
  gem.homepage      = "https://github.com/alphasights/filbert"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency('heroku')
  gem.add_dependency('thor')
end
