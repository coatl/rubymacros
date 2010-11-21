# -*- encoding: utf-8 -*-
dir=File.dirname(__FILE__)
require "#{dir}/lib/rubymacros/version"
RubyMacros::Description=open("#{dir}/README.txt"){|f| f.read[/^==+ ?description[^\n]*?\n *\n?(.*?\n *\n.*?)\n *\n/im,1] }
RubyMacros::Latest_changes="###"+open("#{dir}/History.txt"){|f| f.read[/\A===(.*?)(?====)/m,1] }

Gem::Specification.new do |s|
  s.name = "rubymacros"
  s.version = RubyMacros::VERSION
  s.date = Time.now.strftime("%Y-%m-%d")
  s.authors = ["Caleb Clausen"]
  s.email = %q{caleb (at) inforadical (dot) net}
  s.summary = "RubyMacros is a lisp-like macro pre-processor for Ruby."
  s.description = RubyMacros::Description
  s.homepage = %{http://github.com/coatl/rubymacros}
  s.rubyforge_project = %q{rubymacros}

  s.files = `git ls-files`.split
  s.test_files = %w[test/test_all.rb]
  s.require_paths = ["lib"]
  s.bindir = "bin"
  s.extra_rdoc_files = ["README.txt", "COPYING.LGPL"]
  s.has_rdoc = true
  s.rdoc_options = %w[--main README.txt]

  s.rubygems_version = %q{1.3.0}
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency("redparse", ['>= 0.8.5'])
    else
      s.add_dependency("redparse", ['>= 0.8.5'])
    end
  else
    s.add_dependency("redparse", ['>= 0.8.5'])
  end
end
