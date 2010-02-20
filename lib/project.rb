require 'fileutils'
require 'mail'

class Project
	def initialize(id, data, minici)
		@id=id
		@data=data
		@debug=data['debug'] || false
		@projects_dir=Pathname.new(File.join(data['project_dir'])).expand_path
		@root=File.join(@projects_dir, @id)
		@minici=minici
		@log=''
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
			head_revision=server_revision
			debug("Local: #{current_revision[0..7]} Remote: #{server_revision[0..7]}")
			if current_revision != head_revision then
				# We need to update!
				update_repository

				if File.exists?(last_status_file) then
					last_status=File.read(last_status_file)
				else
					last_status='NONE'
				end

				new_status=run_tests()

				notify_for_status(new_status, last_status)

				write_status_file(new_status)
			else
				# Same revision we've already tested - so, just fall out
				debug("No changes from #{head_revision}...")
			end
			
			# Finished
			debug('Returning...')
		end
	end

private
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

	def notice(msg)
		@log << msg
	end

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
				cmd="cd #{@projects_dir}; git clone #{@data['repo']} #{@id}"
				debug(cmd)
				notice(`#{cmd}`)
			end

		else
			debug("Don't know how to handle \"#{@data['repo']}\"")
		end
	end

	def update_repository
		if @data['repo'] =~ /^git/ then
			old=current_revision
			debug("Pulling latest revision from origin")
			cmd="cd #{@root}; git pull origin #{branch}"
			notice(`#{cmd}`)

			# Get the log between the two
			cmd="cd #{@root}; git log #{old}..#{server_revision} --pretty=full"
			notice(`#{cmd}`)
		end
	end

	def current_revision
		# Get the current revision
		cmd="cd #{@root}; git log -n 1 --pretty=oneline"
		log=`#{cmd}`.strip
		extract_git_hash(log)
	end

	def branch
		@data['branch'] || 'master'
	end

	def server_revision
		return @server_revision unless @server_revision.nil?
		# Find out what the server says
		cmd="cd #{@root}; git ls-remote origin #{branch}"
		debug(cmd)
		log=`#{cmd}`.strip
		@server_revision=extract_git_hash(log)
	end

	def extract_git_hash(string)
		string.match(/([a-f0-9]{40})/)[1].downcase
	end

	def run_tests()
		t1=Time.now
		debug("Running tests for #{@id}...")

		build_log=File.join(@root, 'minici-build.log')
		File.delete(build_log) if File.exist?(build_log)

		cmd="cd #{@root}; #{@data['build']} >> minici-build.log 2>> minici-build.log"
		debug(cmd)
		notice(`#{cmd}`)
		complete=$?

		debug("Finished with status of: #{complete.exitstatus}")

		t2=Time.now
		debug("Tests took #{(t2-t1).to_i} seconds for #{@id}")

		if complete.exitstatus.to_i != 0 then
			return 'ERROR'
		else
			return 'OK'
		end
	end

	def notify_for_status(new_status, old_status)
		if new_status == 'OK' then
			if old_status != 'OK' then
				# It's the first time we've run, or it's a fixed revision.
				# Notify for success!
				target='fixed'
			else
				# It's previously worked
				target='success'
			end
		else
			target='failure'
		end

		debug("Processing notifications for #{target} status")
		if @data['notify'][target]['email'] then
			mail=Mail.new
			mail.from @data['notify']['from'] || 'minici-noreply@example.com'
			mail.to @data['notify'][target]['email'].join(', ')
			mail.subject "#{@data['name']}: #{target.upcase} (#{current_revision})"
			mail.body <<EMAIL
minici build report for #{@data['name']} #{current_revision}

Status: #{target.upcase}

Log:
#{@log}
EMAIL
			
			mail.add_file :filename => "build-#{current_revision}.log", :content => File.read(File.join(@root, "minici-build.log"))

			if @data['notify'][target]['include'] then
				@data['notify'][target]['include'].each do |filename|
					filename=File.join(@root, filename)
					if File.exists?(filename) then
						mail.add_file :filename => filename.gsub(/[^A-Za-z0-9\.\-_]/i,'_'), :content => File.read(filename)
					else
						mail.add_file :filename => filename.gsub(/[^A-Za-z0-9\.\-_]/i,'_'), :content => "FILE \"#{filename}\" IS NOT PRESENT"
					end
				end
			end
			mail.deliver!
		end
		# else, we've no addresses to send to, so no notifications
	end

	def last_status_file
		File.join(@root, '.minici.last-status')
	end
	
	def write_status_file(status)
		File.open(last_status_file, 'w') do |f|
			f << status
		end
	end
end
