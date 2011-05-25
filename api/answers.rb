#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'rexml/document'
require 'CGI'
require 'uri'

#require 'pp'

class Answers
	attr_reader :api_key, :api_host, :api_name

	def initialize(config)
		@app_key = config["api_key"]
		@app_name = config["api_name"]
		@api_host = 'en.stage.api.answers.com'
	end

	def search(query, limit = 1)
		query = CGI::escape(query)
		#pp query
		#url = "http://en.api.answers.com/api/search?appid=#{@app_id}&results=#{limit}&query=#{query}";
		#pp url

		begin
			url = URI.parse('http://'+@api_host+"/api/search?q="+query)

			http = Net::HTTP.new(url.host, url.port)

			path = url.path.empty? ? "/" : url.path

			request = Net::HTTP::Get.new(path+'?'+url.query)
			request.add_field("X-Answers-apikey", @api_key)

			response = http.request(request)

pp response.body

			xml_doc = REXML::Document.new(response.body)
			results = Array.new

			xml_doc['search']['results']['result'].each	do |item|
				result = {}

				results << result
			end

			puts "Received Answers.com response!"

			#top_q = result["all"]["questions"][0]
			top_q = nil
		rescue Exception => e
			puts "Error from "+@api_name+" API: #{e}"
			top_q = nil
		end

		if !top_q.nil?
			data = {
				'source'	=> @api_name,
				'question'	=> top_q["Subject"],
				'answer'	=> top_q["ChosenAnswer"],
				'link'		=> top_q["Link"],
				'category'	=> top_q["CategoryName"],
				'results'	=> result["all"]["count"]
			}
		else
			data = nil
		end

		pp data

		return data
	end
end

#api = Answers.new
#api.search('why is the sky blue?')