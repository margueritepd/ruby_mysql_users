# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mysql_users/version'

Gem::Specification.new do |spec|
  spec.name          = 'mysql_users'
  spec.version       = MysqlUsers::VERSION
  spec.authors       = ['marguerite']
  spec.email         = ['marguerite@pagerduty.com']
  spec.summary       = %q{Manage mysql users with minimal dependencies}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.3.0'
end
