require 'rubygems'
require 'net/http'
require 'json'
require 'CGI'
require 'yaml'

class Yahoo
	attr_reader :app_id, :app_name

	def initialize(config)
		@app_id = config["key"]
		@app_name = config["name"]
	end
	
	def search(query, limit = 1)
		query = CGI::escape(query)
		#pp query
		url = "http://answers.yahooapis.com/AnswersService/V1/questionSearch?appid=#{@app_id}&results=#{limit}&query=#{query}&output=json";
		#pp url
		
		begin
			response = Net::HTTP.get_response(URI.parse(url))
		
			result = JSON.parse(response.body)
			
			puts "Received Yahoo response!"
			
			top_q = result["all"]["questions"][0]
		rescue Exception => e
			puts "Error from Yahoo API: #{e}"
			top_q = nil
		end
		
		if !top_q.nil?
			data = {
				'source'	=> 'Yahoo Answers',
				'question'	=> top_q["Subject"],
				'answer'	=> top_q["ChosenAnswer"],
				'link'		=> top_q["Link"],
				'category'	=> top_q["CategoryName"],
				'results'	=> result["all"]["count"]
			}
		else
			data = nil
		end
		
		return data
	end
end