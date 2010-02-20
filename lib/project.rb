class Project
	def initialize(id, data)
		@id=id
		@data=data
		@debug=data['debug'] || false
		@root=data['root']
	end

	def self.enumerate
		projects={}
		Pathname.glob("**/.minici.yml").each do |config|
			project_id=config.to_s.split(/[\/\\]/)[1]
			projects[project_id]=YAML.load_file(config)['project']
			projects[project_id]['config_file']=config
			projects[project_id]['root']=Pathname.new(config).expand_path.dirname.to_s
		end
		projects
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

	def debug(msg)
		if @debug then
			puts "#{@id}[#{@pid}] - #{msg}"
		end
	end

private
	def check_repository
		if @data['repo'] =~ /^git:\/\// then
			# TODO: Update the repository and see whether there's anything new to run
			if File.exist?(File.join(@root, '.git')) then
				# There's a repo there - update it
			else
				# We need to check out the repo now
				
			end
			# TODO: If there is, run the build command
		else
			debug("Don't know how to handle \"#{@data['repo']}\"")
		end
	end
end
