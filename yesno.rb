def yes_no?
	while true
		print "Yes/No? [y|n]:"
		response = $stdin.gets
		case response
		when /^[yY]/
			puts "Yes"
			return true
		when /^[nN]/, /^$/
			puts "No"
			return false
		end
	end	
end

