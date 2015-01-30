require 'nutella_lib'

# Initialize nutella
nutella.init ARGV

puts "Room places initialization"

# Open the resources database
resources = nutella.persist.getJsonStore("db/resources.json")
groups = nutella.persist.getJsonStore("db/groups.json")

# Create new resource
nutella.net.subscribe("location/add_resource", lambda do |message|
										puts message;
										rid = message["rid"]
										if(rid != nil)
											resources.transaction { 
												resources[rid]={"rid" => rid}; 
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
												puts("Added resource")
											}
										end
									end)

# Remove resource
nutella.net.subscribe("location/remove_resource", lambda do |message|
										puts message;
										rid = message["rid"]
										if(rid != nil)
											resources.transaction { 
												resources.delete(rid); 
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
nutella.net.subscribe("location/add_group", lambda do |message|
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
nutella.net.subscribe("location/remove_group", lambda do |message|
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
nutella.net.subscribe("location/add_resource_to_group", lambda do |message|
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
									end)

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
