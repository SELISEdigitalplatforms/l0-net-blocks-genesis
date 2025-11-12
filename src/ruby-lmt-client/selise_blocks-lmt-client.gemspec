# frozen_string_literal: true

require_relative 'lib/selise_blocks/lmt/version'

Gem::Specification.new do |spec|
  spec.name          = 'selise_blocks-lmt-client'
  spec.version       = SeliseBlocks::LMT::VERSION
  spec.authors       = ['Selise']
  spec.email         = ['support@selise.ch']

  spec.summary       = 'Ruby client library for Selise Blocks LMT (Logging, Monitoring, and Tracing)'
  spec.description   = 'A robust and high-performance Ruby client library for logging and distributed tracing with Azure Service Bus integration.'
  spec.homepage      = 'https://github.com/selise/blocks-lmt-client-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/selise/blocks-lmt-client-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/selise/blocks-lmt-client-ruby/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('{lib,exe}/**/*') + %w[README.md LICENSE]
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'azure-messaging-servicebus', '~> 0.3.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'opentelemetry-sdk', '~> 1.3'
  spec.add_dependency 'opentelemetry-api', '~> 1.2'

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'webmock', '~> 3.18'
end

