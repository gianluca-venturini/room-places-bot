require 'nutella_lib'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

# Configuration part
# ----- Estimote ------

$estimote_url = "https://cloud.estimote.com/v1/beacons";
$estimote_user = "app_20ubacrvcr"
$estimote_pass = "aaa1c1e666642c3643ee74dda4145093"


# Initialize nutella
nutella.init ARGV

puts "Room places initialization"

# Open the resources database
resources = nutella.persist.getJsonStore("db/resources.json")
groups = nutella.persist.getJsonStore("db/groups.json")

# Create new resource
nutella.net.subscribe("location/resource/add", lambda do |message|
										puts message;
										rid = message["rid"]
										type = message["type"]
										model = message["model"]
										if(rid != nil && type != nil && model != nil)
											resources.transaction {
												if(resources[rid] == nil)
													resources[rid]={"rid" => rid,
															"type" => type,
															"model" => model
														};
													publishResourceAdd(resources[rid]);
													puts("Added resource")
												end
											}
											groups.transaction { 
												default=groups["default"];
												if(default == nil)
													default = {}
												end
												if(default["resources"] == nil)
													default["resources"] = [];
												end
												if(!default["resources"].include?(rid))
													default["resources"].push(rid);
												end
												groups["default"] = default;
												puts("Added resource to group default")
											}
										end
									end)

# Remove resource
nutella.net.subscribe("location/resource/remove", lambda do |message|
										puts message;
										rid = message["rid"]
										if(rid != nil)
											resources.transaction {
												resourceCopy = resources[rid];
												resources.delete(rid); 
												publishResourceRemove(resourceCopy);
												puts("Removed resource")
											}
											groups.transaction {
												puts("P")
												puts(groups.roots())
												for group in groups.roots()
													puts("R")
													groups[group]["resources"].delete(rid)
													puts("Removed")
												end
												puts("Removed resource in groups")
											}
										end
									end)

# Create new group
nutella.net.subscribe("location/group/add", lambda do |message|
										puts message;
										group = message["group"]
										if(group != nil)
											groups.transaction { 
												g=groups[group];
												if(g == nil)
													groups[group] = {"resources" => []}
												end
												puts("Added group")
											}
										end
									end)

# Remove group
nutella.net.subscribe("location/group/remove", lambda do |message|
										puts message;
										group = message["group"]
										if(rid != nil)
											groups.transaction { 
												g=groups[group];
												if(g != nil)
													groups.delete(group);
												end
												puts("Removed group")
											}
										end
									end)

# Add resource to group
nutella.net.subscribe("location/group/resource/add", lambda do |message|
										puts message;
										rid = message["rid"]
										group = message["group"]
										if(rid != nil && group != nil)
											resource = nil;
											resources.transaction { 
												resource = resources[rid];
											}
											if(resource != nil)
												puts "The resource exixts"
												groups.transaction { 
													puts "Lol here"
													puts group
													# The group exists and the resource is not yet present
													if(groups[group] != nil && !default["resources"].include?(rid))
														groups[group]["resources"].push(rid);
														puts "Added resources to group"
													else
														puts "The group doesn't exist or the resource is already in it"
													end
												}
											else
												puts "The resource doesn't exist"
											end
										end
									end)

# Update the location of the resources
nutella.net.subscribe("location/update", lambda do |message|
										puts message;
										rid = message["rid"]
										proximity = message["proximity"]
										discrete = message["discrete"]
										continuous = message["continuous"]
										resource = nil
										if(proximity != nil || discrete != nil || continuous != nil)
											resources.transaction { 
												resource = resources[rid];

												if(proximity != nil)
													resource["proximity"] = proximity;
												else
													resource.delete("proximity");
												end

												if(continuous != nil)
													resource["continuous"] = continuous;
												else
													resource.delete("continuous");
												end

												if(discrete != nil)
													resource["discrete"] = discrete;
												else
													resource.delete("discrete");
												end

												resources[rid]=resource; 
												puts "Stored resource"
											}
										end

										if(resource != nil)
											if(resource["proximity"] != nil)
												puts "Proximity resource detected: take coordinates base station"
												resources.transaction { 
													if(resources[resource["proximity"]["rid"]]["continous"] != nil)
														puts "Copy contiuos position base station"
														resource["proximity"]["continous"] = resources[resource["proximity"]["rid"]]["continous"]
													else
														puts "Continous position not present"
													end

													if(resources[resource["proximity"]["rid"]]["discrete"] != nil)
														puts "Copy discrete position base station"
														resource["proximity"]["discrete"] = resources[resource["proximity"]["rid"]]["discrete"]
													else
														puts "Discrete position not present"
													end
												}
											end

											# Send update
											groups.transaction {
												for group in groups.roots()
													puts group
													if(groups[group]["resources"].include?(rid))
														puts "Included"
														nutella.net.publish( "location/moved/"+group+"/"+rid, resource)
													end
												end
											}
											
										end
									end)

# Request the position of a single resource
nutella.net.handle_requests("location/resources") do |request|
	rid = request["rid"]
	group = request["group"]
	reply = nil
	if(rid != nil)
		resources.transaction { 
			reply = resources[rid]; 
		}
		reply
	elsif(group != nil)
		rs = []
		reply = []
		groups.transaction {
			for resource in groups[group]["resources"]
				puts resource
				rs.push(resource)
			end
		}
		for r in rs
			resources.transaction { 
				puts resources[r]
				reply.push(resources[r]); 
			}
		end
		{"resources" => reply}
	else
		resourceList = []

		resources.transaction {
			for resource in resources.roots()
				resourceList.push(resources[resource])
			end
		}
		{"resources" => resourceList}
	end	
end

# Publish an added resource
def publishResourceAdd(resource)
	puts resource
	nutella.net.publish("location/resources/added", {"resources" => [resource]});
end

# Publish a removed resource
def publishResourceRemove(resource)
	puts resource
	nutella.net.publish("location/resources/removed", {"resources" => [resource]});
end

# Request the estimote iBeacons data
nutella.net.handle_requests("location/estimote") do |request|
	puts "Download estimote iBeacon list"

	uri = URI.parse($estimote_url)

	https= Net::HTTP.new(uri.host, uri.port)
	https.use_ssl = true
	#https.verify_mode = OpenSSL::SSL::VERIFY_NONE

	headers = {
		"Accept" => "application/json"
	}

	request = Net::HTTP::Get.new(uri.path, headers)
	request.basic_auth $estimote_user, $estimote_pass


	#response = https.request(request)
	response = https.start {|http| http.request(request) }
	beacons = JSON.parse(response.body)
	{"resources" => beacons}
end

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
