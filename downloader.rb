require "test/unit/assertions"
include Test::Unit::Assertions
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/drive_v3'
require "date"
require 'zlib'
require 'archive/tar/minitar'
require 'concurrent'
require "fileutils"
require_relative "./config.rb"

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

token_store_file = File.expand_path('.credential/credentials.yaml', __dir__)
scope = "https://www.googleapis.com/auth/drive"
client_id = Google::Auth::ClientId.from_file(File.expand_path('.credential/client_secret.json', __dir__))

token_store = Google::Auth::Stores::FileTokenStore.new(file: token_store_file)
authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

credentials = authorizer.get_credentials('default')
if credentials.nil?
  url = authorizer.get_authorization_url(base_url: OOB_URI)
  puts "Open #{url} in your browser and enter the resulting code:"
  code = $stdin.gets
  credentials = authorizer.get_and_store_credentials_from_code(user_id: 'default', code: code, base_url: OOB_URI)
end
service = Google::Apis::DriveV3::DriveService.new
service.authorization = credentials

if ARGV.length == 0 then
	puts "To print help, please type \n\n\truby #{__FILE__} help\n\n"
	exit
end

if ARGV[0] == "help" and ARGV.length == 1 then
	puts "Usage:"
	puts "Show all repositories:\n\truby #{__FILE__} show"
	puts "Show folders in a repository:\n\truby #{__FILE__} show [repository]"
	puts "Show download candidates in a folder:\n\truby #{__FILE__} show [repository] [folder]"
	puts "Download:\n\truby #{__FILE__} download [repository] [folder] [target]"
	exit
end

if ARGV[0] == "show" and ARGV.length == 1 then
	puts "Repositories:"
	DRIVES.keys().each{|name| puts"\t#{name}"}
	exit
end

if ARGV[0] == "show" and ARGV.length == 2 then
	if not DRIVES.keys().include?(ARGV[1]) then
		puts "Cannot find repository: #{ARGV[1]}"
		exit
	else
		drive_id = DRIVES[ARGV[1]]
		root_folders = service.list_files(corpora: 'teamDrive',
						  team_drive_id: DRIVES[ARGV[1]],
						  include_team_drive_items: true,
						  supports_team_drives: true,
						  q:"mimeType='application/vnd.google-apps.folder' and '#{DRIVES[ARGV[1]]}' in parents").files()
		puts "Folders in #{ARGV[1]}:"
		root_folders.each{|folder| puts "\t#{folder.name}"}
		exit
	end
end

if ARGV[0] == "show" and ARGV.length == 3 then
	if not DRIVES.keys().include?(ARGV[1]) then
                puts "Cannot find repository: #{ARGV[1]}"
                exit
        else
		drive_id = DRIVES[ARGV[1]]
                root_folders = service.list_files(corpora: 'teamDrive',
                                                  team_drive_id: DRIVES[ARGV[1]],
                                                  include_team_drive_items: true,
                                                  supports_team_drives: true,
                                                  q:"mimeType='application/vnd.google-apps.folder' and '#{DRIVES[ARGV[1]]}' in parents").files()
		if not root_folders.map{|folder| folder.name}.include?(ARGV[2]) then
			puts "Cannot find folder: #{ARGV[2]}"
			exit
		else
			target_folder = root_folders.select{|folder| folder.name == ARGV[2]}[0]
			file_candidates = service.list_files(q: "'#{target_folder.id}' in parents",
							       corpora: 'teamDrive',
							       include_team_drive_items: true,
							       supports_team_drives: true,
							       team_drive_id: DRIVES[ARGV[1]]
							      ).files()
			puts "Download Candidates:"
			file_candidates.each{|file| puts "\t#{file.name.gsub(".tar.xz","")}"}
			puts "To download,\n\truby #{__FILE__} download #{ARGV[1]} #{ARGV[2]} [target]"
			exit
		end
	end
end

if ARGV[0] == "show" and ARGV.length >= 3 then
	puts "Arguments error. Please refere help:\n\truby #{__FILE__} help"
	exit
end

if ARGV[0] == "download" and ARGV.length == 4 then
	if not DRIVES.keys().include?(ARGV[1]) then
                puts "Cannot find repository: #{ARGV[1]}"
                exit
        else
                drive_id = DRIVES[ARGV[1]]
                root_folders = service.list_files(corpora: 'teamDrive',
                                                  team_drive_id: DRIVES[ARGV[1]],
                                                  include_team_drive_items: true,
                                                  supports_team_drives: true,
                                                  q:"mimeType='application/vnd.google-apps.folder' and '#{DRIVES[ARGV[1]]}' in parents").files()
                if not root_folders.map{|folder| folder.name}.include?(ARGV[2]) then
                        puts "Cannot find folder: #{ARGV[2]}"
                        exit
                else
			target_folder = root_folders.select{|folder| folder.name == ARGV[2]}[0]
                        file_candidates = service.list_files(q: "'#{target_folder.id}' in parents",
                                                               corpora: 'teamDrive',
                                                               include_team_drive_items: true,
                                                               supports_team_drives: true,
                                                               team_drive_id: DRIVES[ARGV[1]]
                                                              ).files()
			if not file_candidates.map{|folder| folder.name}.include?(ARGV[3]) then
				puts "Cannot find download target: #{ARGV[3]}"
                        	exit
			else
				# download
				target = file_candidates.select{|file| file.name == ARGV[3] or file.name == ARGV[3] + ".tar.xz"}[0]
				download_id = target.id
				file_name = target.name
				if file_name.include?(".tar.xz") then
					save_path = File.expand_path("tmp/#{file_name}", __dir__)
				else
					save_path = file_name
				end
				puts "Start downloading..."
				service.get_file(download_id, download_dest:save_path)
				if file_name.include?(".tar.xz") then
					if File.exist?(File.expand_path("pixz-runtime", __dir__))
						# multi
						system("#{File.expand_path("pixz-runtime", __dir__)} -x #{ARGV[0]} < #{save_path} | tar x")
					else
					# single
						system("tar -Jxvf #{save_path}")
					end
				end
				puts "Downloading finished!"
				exit
			end
		end
	end
end

puts "Arguments error. Please refere help:\n\truby #{__FILE__} help"

