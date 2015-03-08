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

# Parse command line arguments
run_id, broker = nutella.parse_args ARGV

# Extract the component_id
component_id = nutella.extract_component_id

# Initialize nutella
nutella.init( run_id, broker, component_id)


puts "Room places initialization"

# Open the resources database
resources = nutella.persist.getJsonStore("db/resources.json")
groups = nutella.persist.getJsonStore("db/groups.json")
room = nutella.persist.getJsonStore("db/room.json")

# Create new resource
nutella.net.subscribe("location/resource/add", lambda do |message, component_id, resource_id|
										puts message;
										rid = message["rid"]
										type = message["type"]
										model = message["model"]
										proximity_range = message["proximity_range"]

										if(proximity_range == nil)
											proximity_range = 0
										end

										if(rid != nil && type != nil && model != nil)
											resources.transaction {
												if(resources[rid] == nil)
													if(type == "STATIC")
														resources[rid]={"rid" => rid,
																"type" => type,
																"model" => model,
																"proximity_range" => proximity_range,
																"parameters" => {}
															};
													elsif(type == "DYNAMIC")
														resources[rid]={"rid" => rid,
																"type" => type,
																"model" => model,
																"parameters" => {}
															};
													end
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
nutella.net.subscribe("location/resource/remove", lambda do |message, component_id, resource_id|
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
nutella.net.subscribe("location/group/add", lambda do |message, component_id, resource_id|
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
nutella.net.subscribe("location/group/remove", lambda do |message, component_id, resource_id|
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
nutella.net.subscribe("location/group/resource/add", lambda do |message, component_id, resource_id|
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
nutella.net.subscribe("location/resource/update", lambda do |message, component_id, resource_id|
										puts message;
										rid = message["rid"]
										type = message["type"]
										proximity = message["proximity"]
										discrete = message["discrete"]
										continuous = message["continuous"]
										parameters = message["parameters"]
										proximity_range = message["proximity_range"]
										resource = nil

										# Retrieve room data
										r = {};

										room.transaction {
											if(room["x"] == nil || room["y"] == nil)
												r["x"] = 10
												r["y"] = 7
											else
												r["x"] = room["x"]
												r["y"] = room["y"]
											end

											if(room["z"] != nil)
												r["z"] = room["z"]
											end
										}

										#if(proximity != nil || discrete != nil || continuous != nil)
										resources.transaction { 
											resource = resources[rid];

											if(proximity != nil)
												resource["proximity"] = proximity;
												resource["proximity"]["timestamp"] = Time.now.to_f
											else
												resource.delete("proximity");
											end

											if(continuous != nil)
												if(continuous["x"] > r["x"]) 
													continuous["x"] = r["x"] 
												end
												if(continuous["x"] < 0)
													continuous["x"] = 0      
												end
												if(continuous["y"] > r["y"])
													continuous["y"] = r["y"] 
												end
												if(continuous["y"] < 0) 
													continuous["y"] = 0      
												end

												resource["continuous"] = continuous;
											else
												resource.delete("continuous");
											end

											if(discrete != nil)
												if(discrete["x"] > r["x"]) 
													discrete["x"] = r["x"] 
												end
												if(discrete["x"] < 0) 
													discrete["x"] = 0      
												end
												if(discrete["y"] > r["y"]) 
													discrete["y"] = r["y"] 
												end
												if(discrete["y"] < 0) 
													discrete["y"] = 0      
												end

												resource["discrete"] = discrete;
											else
												resource.delete("discrete");
											end

											resources[rid]=resource; 
											puts "Stored resource"
										}
										#end

										if(parameters != nil)
											puts parameters
											resources.transaction { 
												resource = resources[rid];
												ps = resource["parameters"]
												for parameter in parameters
													puts parameter
													if(parameter["delete"] == true)
														ps.delete(parameter["key"])
													else
														ps[parameter["key"]] = parameter["value"]
													end
												end
												resource["parameters"] = ps
												resources[rid] = resource
												puts "Stored resource"
											}
										end

										if(type != nil)
											puts "Update type"
											resources.transaction { 
												resource = resources[rid];

												if(type == "STATIC")
													resource["type"] = type;
													resource.delete("proximity");
													if(proximity_range == nil)
														resource["proximity_range"] = 1;
													end
												end

												if(type == "DYNAMIC")
													resource["type"] = type;
													resource.delete("proximity_range");
												end

												resources[rid]=resource; 
												puts "Stored resource"
											}
										end

										if(proximity_range != nil)
											puts "Update proximity range"
											resources.transaction { 
												resource = resources[rid];

												if(resource["type"] == "STATIC")
													resource["proximity_range"]	= proximity_range
												end

												resources[rid]=resource; 
												puts "Stored resource"
											}
										end

										if(proximity == nil && discrete == nil && continuous == nil && parameters == nil)
											resources.transaction { 
												resource = resources[rid];

												resource.delete("proximity");
												resource.delete("continuous");
												resource.delete("discrete");

												resources[rid]=resource; 
												puts "Stored resource"
											}
										end

										if(resource != nil)
											# Join data with base station data
											if(resource["proximity"] != nil)
												puts "Proximity resource detected: take coordinates base station"
												resources.transaction { 
													resource = resources[rid];
													if(resource["proximity"]["rid"] != nil)
														puts "Search for base station " + resource["proximity"]["rid"];
														puts resources[resource["proximity"]["rid"]];
														if(resources[resource["proximity"]["rid"]]["continuous"] != nil)
															puts "Copy contiuos position base station"
															resource["proximity"]["continuous"] = resources[resource["proximity"]["rid"]]["continuous"]
														else
															puts "Continous position not present"
														end

														if(resources[resource["proximity"]["rid"]]["discrete"] != nil)
															puts "Copy discrete position base station"
															resource["proximity"]["discrete"] = resources[resource["proximity"]["rid"]]["discrete"]
														else
															puts "Discrete position not present"
														end
													end
												}
											end

											if(resource["continuous"] != nil)
												resources.transaction { 
													for r in resources.roots()
														resource2 = resources[r]
														if(resource2["proximity"] != nil && resource2["proximity"]["rid"] == resource["rid"])
															resource2["proximity"]["continuous"] = resource["continuous"];
															publishResourceUpdate(resource2)
														end
													end														
												}
											end

											# Send update
											publishResourceUpdate(resource)
											puts "Sent update"

											# Send update to groups
											groups.transaction {
												for group in groups.roots()
													puts group
													if(groups[group]["resources"].include?(rid))
														# Update groups
													end
												end
											}
											
										end
									end)

# Request the position of a single resource
nutella.net.handle_requests("location/resources", lambda do |request, component_id, resource_id|
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
end)

# Update the room size
nutella.net.subscribe("location/room/update", lambda do |message, component_id, resource_id|
												puts message;
												x = message["x"]
												y = message["y"]
												z = message["z"]

												if(x != nil && y != nil)
													r = {}
													room.transaction {
														room["x"] = x
														r["x"] = x

														room["y"] = y
														r["y"] = y

														if(z != nil)
															room["z"] = z
															r["z"] = z
														end
													}
													publishRoomUpdate(r)
													puts "Room updated"
												end
											end)

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

# Publish an updated resource
def publishResourceUpdate(resource)
	puts resource
	nutella.net.publish("location/resources/updated", {"resources" => [resource]});
end

# Publish an updated room
def publishRoomUpdate(r)
	puts r
	nutella.net.publish("location/room/updated", r);
end

# Request the estimote iBeacons data
nutella.net.handle_requests("location/estimote", lambda do |request, component_id, resource_id|
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
end)

# Request the size of the room
nutella.net.handle_requests("location/room", lambda do |request, component_id, resource_id|
	puts "Send the room dimension"

	r = {};

	room.transaction {
		if(room["x"] == nil || room["y"] == nil)
			r["x"] = 10
			r["y"] = 7
		else
			r["x"] = room["x"]
			r["y"] = room["y"]
		end

		if(room["z"] != nil)
			r["z"] = room["z"]
		end
	}
	r
end)

# Routine that delete old proximity beacons
Thread.new do
  while true do
  	puts ">>>"
    resources.transaction {
    	for r in resources.roots()
			resource = resources[r]
			if(resource["proximity"] != nil && resource["proximity"]["timestamp"] != nil)
				if(Time.now.to_f - resource["proximity"]["timestamp"] > 2.0 )
					resource["proximity"] = {}
					puts "Delete proximity resource"
					publishResourceUpdate(resource)
					# Call exit function
				end
			end
		end
    }
    sleep 0.1
  end
end

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
