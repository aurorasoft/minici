require 'rubygems'
require 'pathname'
require 'yaml'
require 'lib/project'
class Minici
	def initialize
		settings_file=[ 'minici.yml', '~/.minici.yml' ].collect { |x| Pathname.new(x).expand_path }.find { |x| File.exists?(x) }
		settings_yml={}
		settings_yml=YAML.load_file(settings_file) if File.exist?(settings_file)
		settings={}.merge(settings_yml)
		@settings=settings

		@settings['project_dir'] ||= 'Projects'

		# If it's not specified, only let processes run for up to 1 hr
		@settings['max_duration'] ||= 3600

		# By default, let five projects build at a time
		@settings['concurrency'] ||= 5

		unless File.exist?(@settings['project_dir']) && File.directory?(@settings['project_dir']) then
			FileUtils.mkdir(@settings['project_dir'])
		end

		Mail.defaults do
			if settings['email']['delivery'] == 'smtp' then
				smtp_settings={}
				settings['email']['smtp'].each do |key, value|
					smtp_settings[key.to_sym]=value
				end
				delivery_method :smtp, smtp_settings
			end
		end
	end

	def start!
		projects=Project.enumerate

		pids=[]

		projects.each_slice(@settings['concurrency'].to_i) do |slice|
			slice.each do |id, project|
				project['debug']=@settings['debug'] if project['debug'].nil?
				project['project_dir']=@settings['project_dir'] if project['project_dir'].nil?
				project['max_duration']=@settings['max_duration'] if project['max_duration'].nil?
				p=Project.new(id, project, self)
				pids << p.fork_and_process!
			end
			Process.waitall
		end
	end
end
