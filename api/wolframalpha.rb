require 'rubygems'
require 'net/http'
require 'json'
require 'CGI'

class Yahoo
	attr_reader :app_id

	def initialize
		@app_id = '2X6LWX-72VYR9YUGH'
		
	end
	
	def search(query, limit = 1)
		query = CGI::escape(query)
		#pp query
		url = "http://answers.yahooapis.com/AnswersService/V1/questionSearch?appid=#{@app_id}&results=#{limit}&query=#{query}&output=json";
		#pp url
		
		begin
			response = Net::HTTP.get_response(URI.parse(url))
		
			result = JSON.parse(response.body)
		
			top_q = result["all"]["questions"][0]
		rescue Exception => e
			top_q = nil
		end
		
		if !top_q.nil?
			data = {
				'source'	=> 'Yahoo Answers',
				'question'	=> top_q["Subject"],
				'answer'	=> top_q["ChosenAnswer"],
				'link'		=> top_q["Link"]
			}
		else
			data = nil
		end
		
		return data
	end
end