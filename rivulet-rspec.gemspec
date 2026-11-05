require_relative 'lib/rivulet/rspec/version'

Gem::Specification.new do |spec|
  spec.name    = 'rivulet-rspec'
  spec.version = Rivulet::RSpec::VERSION
  spec.summary = 'Rivulet RSpec helpers'
  spec.authors = ['Vladimir Dombrovskiy <vold@fastmail.com>']
  spec.license = 'Apache-2.0'

  spec.files         = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

  spec.add_dependency 'oj'
  spec.add_dependency 'rack'
  spec.add_dependency 'rspec'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
