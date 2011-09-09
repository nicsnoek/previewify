Gem::Specification.new do |s|
  s.name        = "previewify"
  s.version     = "0.2.5"
  s.author      = "Nic Snoek"
  s.email       = "nicsnoek@yahoo.com"
  s.homepage    = "http://github.com/nicsnoek/previewify"
  s.summary     = "Preview and publish any model object."
  s.description = "Turns any model into a preview that can be published by calling publish! When the model is accessed in preview mode, the preview model is returned from finders. When the application is in published mode, the latest published model is returned from finders."

  s.files        = Dir["{lib,spec}/**/*", "[A-Z]*"] - ["Gemfile.lock"]
  s.require_path = "lib"

  s.add_development_dependency 'rspec', '~> 2.1.0'
  s.add_development_dependency 'rails', '~> 3.0.0'

  s.required_rubygems_version = ">= 1.3.4"
end