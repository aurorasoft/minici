class Project
	def initialize(id, data)
		@id=id
		@data=data
		@debug=data['debug'] || false
		@root=Pathname.new(File.join('Projects', @id)).expand_path
	end

	def self.enumerate
		YAML.load_file('projects.yml')
	end

	def fork_and_process!
		fork do
			# TODO: Check for lockfile first - return immediately if present
			# TODO: Unless it's been there for a long time, then clear it out
			#       but only if that PID is dead...
			@pid=$$
			debug('Processing...')

			check_repository
			
			# Finished
			debug('Returning...')
		end
	end

	def debug(msg, multicall=false)
		if @debug then
			if multicall then
				if @debug_pending then
					print "#{msg}"
				else
					@debug_pending=true
					print "#{@id}[#{@pid}] - #{msg} "
				end
			else
				if @debug_pending then
					puts "#{msg}"
				else
					puts "#{@id}[#{@pid}] - #{msg} "
				end
				@debug_pending=false
			end
		end
	end

private
	def check_repository
		if @data['repo'] =~ /^git/ then
			# Update the repository and see whether there's anything new to run
			repo_path=File.join(@root, '.git')
			debug("Looking for \"#{repo_path}\"...", true)
			if File.exist?(repo_path) then
				# There's a repo there - update it
				debug("Found!")
			else
				# We need to check out the repo now
				debug("Missing!")
				debug("Cloning repository from #{@data['repo']}")
				cmd="cd #{@root}; git clone #{@data['repo']}"
				debug(cmd)
				system(cmd)
			end

			branch=@data['branch'] || 'master'

			# Just try to update the build
			cmd="cd #{@root}; git ls-remote origin #{branch}"
			debug(cmd)
			log=`#{cmd}`
			debug(log)


			# TODO: If there is, run the build command
		else
			debug("Don't know how to handle \"#{@data['repo']}\"")
		end
	end
end
