require "test/unit/assertions"
include Test::Unit::Assertions
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/drive_v3'
require "date"
require "fileutils"
require_relative "./config.rb"
require_relative "./yesno.rb"

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

token_store_file = File.expand_path('.credential/credentials.yaml', __dir__)
if ARGV.length >= 1 and ARGV[0] == "upload" then
	token_store_file = File.expand_path('.credential/credentials_upload.yaml', __dir__)
end
scope = "https://www.googleapis.com/auth/drive"
client_id = Google::Auth::ClientId.from_file(File.expand_path('.credential/client_secret.json', __dir__))
if ARGV.length >= 1 and ARGV[0] == "upload" then
	client_id = Google::Auth::ClientId.from_file(File.expand_path('.credential/client_secret_uploader.json', __dir__))
end

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
service.client_options.send_timeout_sec = 1200
service.client_options.open_timeout_sec = 1200

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
	puts "Upload:\n\truby #{__FILE__} upload [repository] [folder] [file/folder]"
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
			#puts "Download Candidates:"
			file_candidates.each{|file| puts "#{file.name.gsub(".tar.xz","")}"}
			#puts "To download,\n\truby #{__FILE__} download #{ARGV[1]} #{ARGV[2]} [target]"
			exit
		end
	end
end

if ARGV[0] == "show" and ARGV.length >= 5 then
	puts "Arguments error. Please refere help:\n\truby #{__FILE__} help"
	exit
end

if (ARGV[0] == "download" or ARGV[0] == "show" or ARGV[0] == "upload") and ARGV.length == 4 then
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
			if (ARGV[0] == "download" or ARGV[0] == "show") then
				if not file_candidates.map{|folder| folder.name.gsub(".tar.xz", "")}.include?(ARGV[3]) then
					puts "Cannot find download target: #{ARGV[3]}"
                        		exit
				else
					# download
					if ARGV[0] == "show" then
						puts "You type 'show' in stead of 'download.'"
						puts "Do you want to download target?"
						if not yes_no? then
							exit
						end
					end
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
						if true then
                                                        # multi
							system("pixz -x #{ARGV[0]} < #{save_path} | tar x")
						else
							# single
							system("tar -Jxvf #{save_path}")
						end
					end
					puts "Downloading finished!"
					exit
				end
			elsif ARGV[0] == "upload" then
				# upload
				is_update = false
				if file_candidates.map{|folder| folder.name.gsub(".tar.xz", "")}.include?(ARGV[3]) then
                                	puts "Target already exist: #{ARGV[3]}"
                                	puts "Do you want to override?"
                                	if not yes_no? then
                                	        exit
                                	end
					is_update = true
                        	end
				if is_update then
					target = file_candidates.select{|file| file.name == ARGV[3] or file.name == ARGV[3] + ".tar.xz"}[0]
                                        file_id = target.id
				end
				path = ARGV[3]
                        	is_dir = false
                        	if FileTest.directory?(path) then
                        	        is_dir = true
                        	elsif FileTest.file?(path) then
                        	        id_dir = false
                        	else
                        	        puts "File/directory does not exist"
                        	        exit
                        	end
	
                        	file_name = ARGV[3]
                        	file_path = file_name
				puts "File/folder uploading started"
                        	if is_dir then
                        	        # compress
                        	        file_name += ".tar.xz"
                        	        file_path = File.expand_path(file_name, File.expand_path("tmp/", __dir__))
                        	        if true then
                        	                # multi
						system("tar cf - #{ARGV[3]} | pixz > #{file_path}")
                        	        else
                        	                #single
                        	                system("tar -Jcf #{file_path} #{ARGV[3]}")
                        	        end
                        	end
				if is_update then
					file_object = {
                                	        name: file_name,
                                        	modifiedTime: DateTime.now
                                	}
					service.update_file(
						file_id,
						file_object,
						supports_team_drives: true,
						upload_source: file_path
					)
				else
					file_object = {
                                        	name: file_name,
                                        	parents: [target_folder.id],
                                        	modifiedTime: DateTime.now
                                	}
					service.create_file(
						file_object,
						supports_team_drives: true,
						upload_source: file_path
					)
				end
				if is_dir then
					FileUtils.rm(file_path)
				end
				puts "Upload finished"
                        	exit
			end
		end
	end
end

