#!/bin/env ruby
#

require 'pathname'
require 'yaml'
require 'lib/project'

# Put in crontab to run every X minutes
# We'll fork off the builds for each project
# Create folders under Projects
# In those files, place a .minici.yml file, like
# name: MD4
# repo: git://git@aurorasoft.com.au:au_md4.git
# build: rake cruise
# notify:
#   failure:
#     include:
#       - build.log
#       - log/cucumber.log
#     email:
#       - jstirk@aurorasoft.com.au
#   success:
#   fixed:
#     email:
#       - jstirk@aurorasoft.com.au

projects=Project.enumerate

projects.each do |id, project|
	p=Project.new(id, project)
	p.fork_and_process!
end
Process.wait


