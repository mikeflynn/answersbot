require 'rubygems'
require 'json'
require 'mongo'

class Mongolog
	attr_reader :connection

	def initialize(dbname)
		begin
			@connection = Mongo::Connection.new("localhost", 27017).db(dbname)
		rescue Exception => e
			puts "Error: No mongo connection."
		end
	end
	
	def get_collection(name)
		return @connection.collection(name)
	end
	
	def log(obj)
		if(obj.empty? || obj.class != 'Hash')
			begin 	
				collection = get_collection('log')
				result = collection.insert(obj)
				return true
			rescue
				return false
			end
		end

		return false
	end
	
	def history(user)
		if(!user.empty?)
			begin
				collection = get_collection('log')
				results = collection.find({'user' => user})

				return results
			rescue
				return nil
			end
		end
		
		return nil
	end
end