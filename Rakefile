require 'rubygems'
require 'rake/gempackagetask'
require 'fileutils'
require './lib/riak'

gemspec = Gem::Specification.new do |gem|
  gem.name = "riakpb"
  gem.summary = %Q{riakpb is a protocol buffer client for Riak--the distributed database by Basho.}
  gem.description = %Q{riakpb is a protocol buffer client for Riak--the distributed database by Basho.}
  gem.version = Riak::VERSION
  gem.email = "me@inherentlylame.com"
  gem.homepage = "http://github.com/aitrus/riak-pbclient"
  gem.authors = ["Scott Gonyea"]
  gem.add_development_dependency "rspec", "~>2.0.0.beta.9"
  gem.add_dependency "activesupport", ">= 2.3.5"
  gem.add_dependency "ruby_protobuf", ">=0.4.4"

  files = FileList["**/*"]
  files.exclude /\.DS_Store/
  files.exclude /\#/
  files.exclude /~/
  files.exclude /\.swp/
  files.exclude '**/._*'
  files.exclude '**/*.orig'
  files.exclude '**/*.rej'
  files.exclude /^pkg/
  files.exclude 'riak-client.gemspec'

  gem.files = files.to_a

  gem.test_files = FileList["spec/**/*.rb"].to_a
end

# Gem packaging tasks
Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.need_zip = false
  pkg.need_tar = false
end

task :gem => :gemspec

desc %{Build the gemspec file.}
task :gemspec do
  gemspec.validate
  File.open("#{gemspec.name}.gemspec", 'w'){|f| f.write gemspec.to_ruby }
end

desc %{Release the gem to RubyGems.org}
task :release => :gem do
  "gem push pkg/#{gemspec.name}-#{gemspec.version}.gem"
end

require 'rspec/core'
require 'rspec/core/rake_task'

desc "Run Unit Specs Only"
Rspec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/riak/**/*_spec.rb"
end

namespace :spec do
  desc "Run Integration Specs Only"
  Rspec::Core::RakeTask.new(:integration) do |spec|
    spec.pattern = "spec/integration/**/*_spec.rb"
  end

  desc "Run All Specs"
  Rspec::Core::RakeTask.new(:all) do |spec|
    spec.pattern = Rake::FileList["spec/**/*_spec.rb"]
  end
end

# TODO - want other tests/tasks run by default? Add them to the list
# remove_task :default
# task :default => [:spec, :features]

