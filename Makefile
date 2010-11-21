name=RubyMacros
lname=rubymacros
gemname=rubymacros

#everything after this line is generic

version=$(shell ruby -r ./lib/$(lname)/version.rb -e "puts $(name)::VERSION")
filelist=$(shell git ls-files)

.PHONY: all test docs gem tar pkg email
all: test

test:
	ruby -Ilib test/test_all.rb

docs:
	rdoc lib/*

pkg: gem tar

gem:
	gem build $(lname).gemspec

tar:
	tar cf - $(filelist) | ( mkdir $(gemname)-$(version); cd $(gemname)-$(version); tar xf - )
	tar czf $(gemname)-$(version).tar.gz $(gemname)-$(version)
	rm -rf $(gemname)-$(version)

email: README.txt History.txt
	ruby -e ' \
  require "rubygems"; \
  load "./$(lname).gemspec"; \
  spec= Gem::Specification.list.find{|x| x.name=="$(gemname)"}; \
  puts "\
Subject: [ANN] $(name) #{spec.version} Released \
\n\n$(name) version #{spec.version} has been released! \n\n\
#{Array(spec.homepage).map{|url| " * #{url}\n" }} \
 \n\
#{$(name)::Description} \
\n\nChanges:\n\n \
#{$(name)::Latest_changes} \
"\
'
