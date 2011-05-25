#!/usr/bin/env ruby

require 'rubygems'
require 'xmpp4r/client'
require 'xmpp4r/roster'
require 'xmpp4r/vcard'
require 'base64'
require 'pp'
require 'yaml'
require 'db/mongolog'

class Chatbot
	include Jabber
	
	attr_accessor :jid, :password, :fullname, :nickname, :photo, :status, :admins, :priority, :api
	attr_reader :client, :roster
	
	def initialize(config, debug = false)
		self.admins = ["mfflynn@gmail.com"]
		
		self.jid = config["username"]
		self.password = config["password"]
		self.fullname = config["fullname"]
		self.nickname = config["nickname"]
		self.photo = config["photo"]
		self.status = config["status"]
		self.priority = config["priority"]
		
		self.api = config["api"]

		output("Connecting as "+@fullname+"...")
		
		@client = Client.new(JID::new(self.jid + '/chatbot'))
		Jabber::debug = debug
		
		connect
	end
	
	def connect
		@client.connect
		@client.auth(@password)
		
		change_status(@status, :chat, @priority)
		
		@roster = Roster::Helper.new(@client)
		
		output "Client connected!"
		
		add_callbacks
		
		set_metadata(@fullname, @nickname, @photo)
	end
	
	def add_callbacks

		output "Starting subscription callback..."

		# Auto-add new friend requests
		@roster.add_subscription_request_callback do |item,pres|
			output "Incoming friend request from "+pres.from.to_s
		
			@roster.accept_subscription(pres.from)
			
			#x = Presence.new.set_type(:subscribe).set_to(pres.from)
			#@client.send(x)
			
			send_message(pres.from, "Hi new friend! Feel free to ask me some questions.")
		end
		
		output "Starting request callback..."

		# Message responding...
		@client.add_message_callback do |t|
			if(t.body.to_s != '')
				rqsttype = request_type(t)
			
				output "Incoming "+t.type.to_s+" message from \""+clean_username(t.from)+"\": " + t.body.to_s
				output "Type: "+rqsttype

				log = {
					"request"	=> t.body.to_s,
					"timestamp"	=> Time.new,
					"user"		=> clean_username(t.from),
					"type"		=> rqsttype
				}

				case rqsttype
				when "question"
					response = [
						"Hmm...let me look that up for you!",
						"Great question! One second please, while I look that up!",
						"Well I'm just a chat bot, but let me ask Answers.com...",
						"Really? Really?! You don't know that! I'm not even sure I want to tell you. ...Eh, ok.",
						"One answer coming up!"		
					]
					send_message(t.from.to_s, response[rand(response.size)])
					
					th = Thread.new do
						data = lookup_answer(t.body.to_s, self.api)
						
						log["answer"] = {
							'source'	=> self.api['name'],
							'return'	=> data
						}
						
						if(data.nil?)
							message = "Whoops! We couldn't find an answer for that! Sorry"
						else
							message = data["question"]+"\n\n"
							message += data["answer"]+"\n\n"
							message += "From "+data["source"]+": "+data["link"]
						end
						
						send_message(t.from.to_s, message)
					end
				when "help"
					message = "You can ask me a question and I'll do my best to go look it up for you from Answers.com!"
					send_message(t.from.to_s, message)
				when "shutdown"
					signoff
				when "personal"
					response = [
						"Don't worry about me. What's on your mind?",
						"I'm not really sure. The internet can't search my heart...yet.",
						"Dude. I'm a computer.",
						"I think that's a little personal isn't it?!"
					]
					send_message(t.from.to_s, response[rand(response.size)])
				when "greeting"
					response = [
						"Hi!",
						"Howdy partner!",
						"Good day sir!",
						"Hi...and might I say, that shirt looks great on you!",
						"I was just wondering if you were going to say hello!"
					]
					send_message(t.from.to_s, response[rand(response.size)])
				else
					response = [
						"I have no idea what you're talking about.",
						"I'm not exactly sure what you meant by that, but I have a feeling it's dirty.",
						"Not even Answers.com can help me with that one.",
						"Right back at ya slick!",
						"What?"		
					]
					send_message(t.from.to_s, response[rand(response.size)])
				end
				
				#mongolog = Mongolog.new('jabber')
				#mongolog.log(log)
			end
		end
	end
	
	def send_message(to, body, subject = '')
		msg = Message::new
		msg.to = to
		
		msg.subject = subject
		msg.set_type(:normal)
		msg.set_id('1')
		
		if(body.class != String) 
			body = body.to_s
		end
		
		msg.body = body
		
		@client.send(msg)	
	end
	
	def set_metadata(full_name, nickname, image_file = '')
		avatar_sha1 = nil
		Thread.new do
			vcard_helper = Jabber::Vcard::Helper.new(@client)
			vcard = vcard_helper.get
			
			vcard["FN"] = full_name
			vcard["NICKNAME"] = nickname

			if (image_file != '')
				type = get_filetype(image_file)
				if(type)
					image_file = File.new(image_file, "r")
					vcard["PHOTO/TYPE"] = type
					image_b64 = Base64.encode64(image_file.read())
					#image_file.rewind
					avatar_sha1 = Digest::SHA1.hexdigest(image_file.read())
					vcard["PHOTO/BINVAL"] = image_b64
				end
			end
			begin
				vcard_helper.set(vcard)
			rescue Exception => e
				output "Vcard update failed: '#{e.to_s.inspect}'"
			end
		end
	end
	
	def get_filetype(filename)
		types = {
			".png"	=> "image/png",
			".jpg"	=> "image/jpeg",
			".gif"	=> "image/gif"
		}
		return types[File.extname(filename)]
	end
	
	def change_status(message = '', type=:chat, priority = 1)
		client.send(Jabber::Presence.new.set_show(type).set_status(message).set_priority(priority))
	end
	
	def request_type(request)
		body = request.body.to_s
		
		# Is it help?
		if(body == "help")
			return "help"
		end
		
		# Are they saying hello?
		if(body.match(/\b(hello|hi|sup|hey|yo|howdy)\b(\?|\!|\.)*/))
			return "greeting"
		end
		
		# Is it a question?
		if(body.match(/.+\?$/i))
			# About me?
			if(body.match(/\b(you|your)\b/))
				return "personal"
			else
				return "question"
			end
		end

		# Affirmatives?
		if(body.match(/\b(yes|yup|sure)\b/))
			return "affirmative"
		end

		# Negatives?
		if(body.match(/\b(no|nope|not)\b/))
			return "negative"
		end
		
		# Admin shutdown command.
		if(body == "shutdown" && @admins.include?(clean_username(request.from)))
			return "shutdown"
		end
		
		# ...well we don't know then
		return "unknown"
	end
	
	def clean_username(jabber_user)
		from_ar = jabber_user.to_s.split('/')
		return from_ar[0]
	end
	
	def lookup_answer(question, api)
		output "Requesting answer from "+api["name"]

		require "api/"+api["file"]
		obj = Object::const_get(api["file"].capitalize).new(api)
		return obj.search(question)
	end
	
	def signoff
		output "Chatbot has been signed off."
	
		@client.close
	end
	
	def output(text)
		if(text.class != String)
			text = text.to_s
		end
		
		puts "#{Time.new}: "+text
	end
end

if(ARGV[0] != '') 
	config = YAML.load_file(ARGV[0])
	bot = Chatbot.new(config, ARGV[1])
	Thread.stop
end

bot.signoff