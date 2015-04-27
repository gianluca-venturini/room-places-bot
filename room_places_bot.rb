require 'nutella_lib'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

# Configuration part
# ----- Estimote ------

$estimote_url = 'https://cloud.estimote.com/v1/beacons'
$estimote_user = 'app_20ubacrvcr'
$estimote_pass = 'aaa1c1e666642c3643ee74dda4145093'

# Parse command line arguments
broker, app_id, run_id = nutella.parse_args ARGV
# Extract the component_id
component_id = nutella.extract_component_id
# Initialize nutella
nutella.init(broker, app_id, run_id, component_id)

# Buffer object that caches all the updates
class RoomPlacesCachePublish

  def initialize
    @resource_updated = {}
    @resource_added = []
    @resource_removed = []
    @resource_entered = {}
    @resource_exited = {}

    # Semaphores for threads safety
    @s1 = Mutex.new
    @s2 = Mutex.new
    @s3 = Mutex.new
    @s4 = Mutex.new
    @s5 = Mutex.new
    @s6 = Mutex.new
    @s7 = Mutex.new
    @s8 = Mutex.new
    @s9 = Mutex.new
    @s10 = Mutex.new
  end

  def resources_update(resources)
    @s1.synchronize {
      resources.each do |resource|
        @resource_updated[resource['rid']] = resource
      end
    }
  end

  def resources_add(resources)
    @s2.synchronize {
      @resource_added += resources
    }
  end

  def resources_remove(resources)
    @s3.synchronize {
      @resource_removed += resources
    }
  end

  def resources_enter(resources, baseStationRid)
    @s4.synchronize {
      if @resource_entered[baseStationRid] == nil
        @resource_entered[baseStationRid] = []
      end
      @resource_entered[baseStationRid] += resources
    }
  end

  def resources_exit(resources, baseStationRid)
    @s5.synchronize {
      if @resource_exited[baseStationRid] == nil
        @resource_exited[baseStationRid] = []
      end
      @resource_exited[baseStationRid] += resources
    }
  end

  def publish_update
    @s6.synchronize {
      if @resource_updated.length > 0
        nutella.net.publish('location/resources/updated', {:resources => @resource_updated.values})
        @resource_updated = {}
      end
    }
  end

  def publish_add
    @s7.synchronize {
      if @resource_added.length > 0
        nutella.net.publish('location/resources/added', {:resources => @resource_added})
        @resource_added = []
      end
    }
  end

  def publish_remove
    @s8.synchronize {
      if @resource_removed.length > 0
        nutella.net.publish('location/resources/removed', {:resources => @resource_removed})
        @resource_removed = []
      end
    }
  end

  def publish_enter
    @s9.synchronize {
      @resource_entered.each do |baseStationRid, resources|
        nutella.net.publish("location/resource/static/#{baseStationRid}/enter", {'resources' => resources})
      end
      @resource_entered = {}
    }
  end

  def publish_exit
    @s10.synchronize {
      @resource_exited.each do |baseStationRid, resources|
        nutella.net.publish("location/resource/static/#{baseStationRid}/exit", {'resources' => resources})
      end
      @resource_exited = {}
    }
  end

end

$cache = RoomPlacesCachePublish.new

puts 'Room places initialization'

# Open the resources database
$resources = nutella.persist.get_json_object_store('resources')
#$resources = nutella.persist.get_mongo_object_store('resources')
$groups = nutella.persist.get_json_object_store('groups')
$room = nutella.persist.get_json_object_store('room')
$discrete_tracking = nutella.persist.get_json_object_store('discrete_tracking')

# Create new resource
nutella.net.subscribe('location/resource/add', lambda do |message, from|
										puts message
										rid = message['rid']
										type = message['type']
										model = message['model']
										proximity_range = message['proximity_range']

										if proximity_range == nil
											proximity_range = 0
										end

										if rid != nil && type != nil && model != nil
                      if $resources[rid] == nil
                        if type == 'STATIC'
                          $resources[rid]={:rid => rid,
                              :type => type,
                              :model => model,
                              :proximity_range => proximity_range,
                              :parameters => {}
                            };
                        elsif type == 'DYNAMIC'
                          $resources[rid]={:rid => rid,
                              :type => type,
                              :model => model,
                              :parameters => {}
                            }
                        end
                        publishResourceAdd($resources[rid])
                        $cache.publish_add
                        puts('Added resource')
                      end

										end
									end)

# Remove resource
nutella.net.subscribe('location/resource/remove', lambda do |message, from|
										puts message
										rid = message['rid']
										if rid != nil

                      resourceCopy = $resources[rid]
                      $resources.delete(rid)
                      publishResourceRemove(resourceCopy)
                      $cache.publish_remove
                      puts('Removed resource')

										end
									end)

# Create new group
nutella.net.subscribe('location/group/add', lambda do |message, from|
										puts message
										group = message['group']
										if group != nil

                      g=$groups[group]
                      if g == nil
                        $groups[group] = {:resources => []}
                      end
                      puts('Added group')

										end
									end)

# Remove group
nutella.net.subscribe('location/group/remove', lambda do |message, from|
										puts message
										group = message['group']
										if rid != nil
                      g=$groups[group]
                      if g != nil
                        $groups.delete(group);
                      end
                      puts('Removed group')

										end
									end)

# Add resource to group
nutella.net.subscribe('location/group/resource/add', lambda do |message, from|
										puts message
										rid = message['rid']
										group = message['group']
										if rid != nil && group != nil
											resource = nil
											resource = $resources[rid]

											if resource != nil
												puts 'The resource exixts'
                        puts group
                        # The group exists and the resource is not yet present
                        if $groups[group] != nil && !default['resources'].include?(rid)
                          $groups[group]['resources'].push(rid)
                          puts 'Added resources to group'
                        else
                          puts 'The group doesn\'t exist or the resource is already in it'
                        end

											else
												puts 'The resource doesn\'t exist'
											end
										end
									end)

# Update the location of the resources
nutella.net.subscribe('location/resource/update', lambda do |message, from|
    updateResource(message)

    $cache.publish_update
    $cache.publish_enter
    $cache.publish_exit
  end)

# Update the location of the resources
nutella.net.subscribe('location/resources/update', lambda do |message, from|
    resources = message['resources']
    if resources != nil
      resources.each do |resource|
        updateResource(resource)
      end
    end

    $cache.publish_update
    $cache.publish_enter
    $cache.publish_exit
  end)

def updateResource(updatedResource)
  rid = updatedResource['rid']
  type = updatedResource['type']
  proximity = updatedResource['proximity']
  discrete = updatedResource['discrete']
  continuous = updatedResource['continuous']
  parameters = updatedResource['parameters']
  proximity_range = updatedResource['proximity_range']
  resource = nil

  # Retrieve $room data
  r = {}

  if $room['x'] == nil || $room['y'] == nil
    r['x'] = 10
    r['y'] = 7
  else
    r['x'] = $room['x']
    r['y'] = $room['y']
  end

  if $room['z'] != nil
    r['z'] = $room['z']
  end


  resource = $resources[rid]

  if resource == nil
    return
  end

  if proximity != nil && proximity['rid'] != nil && proximity['distance'] != nil
    baseStation = $resources[proximity['rid']]

    if baseStation != nil

      if baseStation['proximity_range'] >= proximity['distance']
        if resource['proximity'] != nil && resource['proximity']['rid'] && resource['proximity']['distance']
          oldBaseStationRid = resource['proximity']['rid']
          if resource['proximity']['rid'] != proximity['rid']
            #if proximity['distance'] < resource['proximity']['distance']
              resource['proximity'] = proximity
              resource['proximity']['timestamp'] = Time.now.to_f
              publishResourceExit(resource, baseStation['rid'])
              publishResourceEnter(resource, resource['proximity']['rid'])
            #end
          else
            resource['proximity'] = proximity
            resource['proximity']['timestamp'] = Time.now.to_f
          end
          computeResourceUpdate(oldBaseStationRid)
        else
          resource['proximity'] = proximity
          resource['proximity']['timestamp'] = Time.now.to_f
          publishResourceEnter(resource, resource['proximity']['rid'])
        end
      end
    end
  elsif proximity == nil
    resource.delete('proximity')
  else
    resource['proximity'] = {}
  end

  if continuous != nil
    if continuous['x'] > r['x']
      continuous['x'] = r['x']
    end
    if continuous['x'] < 0
      continuous['x'] = 0
    end
    if continuous['y'] > r['y']
      continuous['y'] = r['y']
    end
    if continuous['y'] < 0
      continuous['y'] = 0
    end

    resource['continuous'] = continuous
  else
    if resource != nil && resource['continuous'] != nil
      resource.delete('continuous');
    end
  end

  if $discrete_tracking['x'] != nil
    if discrete != nil

      # Translate all coordinates in numbers
      if discrete['x'].instance_of? String
        discrete['x'] = discrete['x'].downcase.ord - 'a'.ord
      end
      if discrete['y'].instance_of? String
        discrete['y'] = discrete['y'].downcase.ord - 'a'.ord
      end


      if discrete['x'] > $discrete_tracking['n_x'] - 1
        discrete['x'] = $discrete_tracking['n_x'] - 1
      end
      if discrete['x'] < 0
        discrete['x'] = 0
      end
      if discrete['y'] > $discrete_tracking['n_y'] - 1
        discrete['y'] = $discrete_tracking['n_y'] - 1
      end
      if discrete['y'] < 0
        discrete['y'] = 0
      end

      resource['discrete'] = discrete
    else
      if resource != nil && resource['discrete'] != nil
        resource.delete('discrete');
      end
    end
  end

  if parameters != nil
    puts parameters
    ps = resource['parameters']
    for parameter in parameters
      puts parameter
      if parameter['delete'] != nil
        ps.delete(parameter['key'])
      else
        puts "--------"
        puts parameter['key']
        puts parameter['value']
        ps[parameter['key']] = parameter['value']
      end
    end
    resource['parameters'] = ps
  end

  if type != nil
    puts 'Update type'

    if type == 'STATIC'
      resource['type'] = type
      resource.delete('proximity')
      if proximity_range == nil
        resource['proximity_range'] = 1;
      end
    end

    if type == 'DYNAMIC'
      resource['type'] = type
      resource.delete('proximity_range')
    end

    puts 'Stored resource'
  end

  if proximity_range != nil
    puts 'Update proximity range'

    if resource['type'] == 'STATIC'
      resource['proximity_range']	= proximity_range
    end

    puts 'Stored resource'

  end

  if proximity == nil && discrete == nil && continuous == nil && parameters == nil

    resource.delete('proximity')
    resource.delete('continuous')
    resource.delete('discrete')

    puts 'Stored resource'

  end

  $resources[rid]=resource
  computeResourceUpdate(rid)

end

# Request the position of a single resource
nutella.net.handle_requests('location/resources', lambda do |request, from|
  puts 'Send list of resources'

	rid = request['rid']
	group = request['group']
	reply = nil
	if rid != nil
    reply = $resources[rid]

		reply
	elsif group != nil
		rs = []
		reply = []
    for resource in $groups[group]['resources']
      puts resource
      rs.push(resource)
    end

		for r in rs
      resource = $resources[resource]
      # Translate discrete coordinate
      if resource['discrete'] != nil
        resource['discrete'] = translateDiscreteCoordinates(resource['discrete'])
      end
      reply.push(resource)

		end
		{:resources => reply}
	else
		resourceList = []

    for resource in $resources.keys()
      resource = $resources[resource]
      # Translate discrete coordinate
      if resource['discrete'] != nil
        resource['discrete'] = translateDiscreteCoordinates(resource['discrete'])
      end
      resourceList.push(resource)
    end

		{:resources => resourceList}
	end
end)

# Update the room size
nutella.net.subscribe('location/room/update', lambda do |message, from|
												puts message
												x = message['x']
												y = message['y']
												z = message['z']

												if x != nil && y != nil
													r = {}
                          $room['x'] = x
                          r['x'] = x

                          $room['y'] = y
                          r['y'] = y

                          if z != nil
                            $room['z'] = z
                            r['z'] = z
                          end

													publishRoomUpdate(r)
													puts 'Room updated'
												end
											end)

# Compute and publish resource
def computeResourceUpdate(rid)

  resource = nil

  resource = $resources[rid]

  if resource != nil
    if resource['proximity'] != nil
      puts 'Proximity resource detected: take coordinates base station'

      if resource['proximity']['rid'] != nil
        puts 'Search for base station ' + resource['proximity']['rid']
        baseStation = nil
        baseStation = $resources[resource['proximity']['rid']]

        puts baseStation
        if baseStation != nil && baseStation['continuous'] != nil
          puts 'Copy continuous position base station'
          resource['proximity']['continuous'] = baseStation['continuous']

          # Update basic station
          computeResourceUpdate(resource['proximity']['rid'])
        else
          puts 'Continuous position not present'
        end

        if baseStation != nil && baseStation['discrete'] != nil
          puts 'Copy discrete position base station'
          resource['proximity']['discrete'] = baseStation['discrete']
        else
          puts 'Discrete position not present'
        end
      end
    end

    $resources[rid] = resource

=begin
    if resource['continuous'] != nil
      counter = 0 # Number of proximity beacons tracked from this station
      for r in $resources.keys()
        resource2 = $resources[r]
        if resource2['proximity'] != nil && resource2['proximity']['rid'] == resource['rid']
          counter += 1
          resource2['proximity']['continuous'] = resource['continuous']
          $resources[r] = resource2
          publishResourceUpdate(resource2)
        end
      end
      puts counter
      resource['number_resources'] = counter
    end
=end

    # Translate discrete coordinate
    if resource['discrete'] != nil
      resource['discrete'] = translateDiscreteCoordinates(resource['discrete'])
    end

    # Send update
    publishResourceUpdate(resource)
    puts 'Sent update'

  end
end

def translateDiscreteCoordinates(discrete)
  if discrete != nil && $discrete_tracking['t_x'] != nil && $discrete_tracking['t_y'] != nil
    if $discrete_tracking['t_x'] == 'LETTER'
      discrete['x'] = (discrete['x'] + 'a'.ord).chr
    end
    if $discrete_tracking['t_y'] == 'LETTER'
      discrete['y'] = (discrete['y'] + 'a'.ord).chr
    end
  end
  discrete
end

# Update the room size
nutella.net.subscribe('location/tracking/discrete/update', lambda do |message, from|
 tracking = message['tracking']

 if tracking != nil
   x = tracking['x']
   y = tracking['y']
   width = tracking['width']
   height = tracking['height']
   n_x = tracking['n_x']
   n_y = tracking['n_y']
   t_x = tracking['t_x']
   t_y = tracking['t_y']

   if x != nil && y != nil && width != nil && height != nil && n_x != nil && n_y != nil && t_x != nil && t_y != nil
     $discrete_tracking['x'] = x
     $discrete_tracking['y'] = y
     $discrete_tracking['width'] = width
     $discrete_tracking['height'] = height
     $discrete_tracking['n_x'] = n_x
     $discrete_tracking['n_y'] = n_y
     $discrete_tracking['t_x'] = t_x
     $discrete_tracking['t_y'] = t_y
   else
     $discrete_tracking['x'] = nil
     $discrete_tracking['y'] = nil
     $discrete_tracking['width'] = nil
     $discrete_tracking['height'] = nil
     $discrete_tracking['n_x'] = nil
     $discrete_tracking['n_y'] = nil
     $discrete_tracking['t_x'] = nil
     $discrete_tracking['t_y'] = nil
   end

   publishDiscreteUpdate()
 end

end)


# Publish an added resource
def publishResourceAdd(resource)
	puts resource
  $cache.resources_add([resource])
	#nutella.net.publish('location/resources/added', {:resources => [resource]})
end

# Publish a removed resource
def publishResourceRemove(resource)
	puts resource
  $cache.resources_remove([resource])
	#nutella.net.publish('location/resources/removed', {:resources => [resource]})
end

# Publish an updated resource
def publishResourceUpdate(resource)
	puts resource
  $cache.resources_update([resource])
	#nutella.net.publish('location/resources/updated', {:resources => [resource]})
end

# Publish an updated room
def publishRoomUpdate(room)
	puts room
	nutella.net.publish('location/room/updated', room)
end

# Publish resources enter base station proximity area
def publishResourcesEnter(resources, baseStationRid)
  puts resources
  puts baseStationRid
  #message = {:resources => resources}
  #nutella.net.publish("location/resource/static/#{baseStationRid}/enter", message)
  $cache.resources_enter(resources, baseStationRid)
end

# Publish resources exit base station proximity area
def publishResourcesExit(resources, baseStationRid)
  puts resources
  puts baseStationRid
  #message = {:resources => resources}
  #nutella.net.publish("location/resource/static/#{baseStationRid}/exit", message)
  $cache.resources_exit(resources, baseStationRid)
end

# Publish resource enter base station proximity area
def publishResourceEnter(resource, baseStationRid)
  publishResourcesEnter([resource], baseStationRid)
end

# Publish resource enter base station proximity area
def publishResourceExit(resource, baseStationRid)
  publishResourcesExit([resource], baseStationRid)
end

# Publish tracking system update
def publishDiscreteUpdate()

  x = $discrete_tracking['x']
  y = $discrete_tracking['y']
  width = $discrete_tracking['width']
  height = $discrete_tracking['height']
  n_x = $discrete_tracking['n_x']
  n_y = $discrete_tracking['n_y']
  t_x = $discrete_tracking['t_x']
  t_y = $discrete_tracking['t_y']

  if x != nil && y != nil && width != nil && height != nil && n_x != nil && n_y != nil && t_x != nil && t_y != nil
    message = {
        :x => x,
        :y => y,
        :width => width,
        :height => height,
        :n_x => n_x,
        :n_y => n_y,
        :t_x => t_x,
        :t_y => t_y
    }
    nutella.net.publish('location/tracking/discrete/updated', {:tracking => message})

    # Update all the discrete resources
    for r in $resources.keys()
      resource = $resources[r]
      if resource['discrete'] != nil
        computeResourceUpdate(r)
      end
    end

  else
    nutella.net.publish('location/tracking/discrete/updated', {:tracking => {}})
  end

end

# Request the estimote iBeacons data
nutella.net.handle_requests('location/estimote', lambda do |request, from|
	puts 'Download estimote iBeacon list'

	uri = URI.parse($estimote_url)

	https= Net::HTTP.new(uri.host, uri.port)
	https.use_ssl = true
	#https.verify_mode = OpenSSL::SSL::VERIFY_NONE

	headers = {
		:Accept => 'application/json'
	}

	request = Net::HTTP::Get.new(uri.path, headers)
	request.basic_auth $estimote_user, $estimote_pass


	#response = https.request(request)
	response = https.start {|http| http.request(request) }
	beacons = JSON.parse(response.body)
	{:resources => beacons}
end)

# Request the size of the room
nutella.net.handle_requests('location/room', lambda do |request, from|
	puts 'Send the room dimension'

	r = {}

  if $room['x'] == nil || $room['y'] == nil
    r['x'] = 10
    r['y'] = 7
  else
    r['x'] = $room['x']
    r['y'] = $room['y']
  end

  if $room['z'] != nil
    r['z'] = $room['z']
  end

	r
end)

# Request discrete tracking system
nutella.net.handle_requests('location/tracking/discrete', lambda do |request, from|
  puts 'Send the discrete tracking system'

  x = $discrete_tracking['x']
  y = $discrete_tracking['y']
  width = $discrete_tracking['width']
  height = $discrete_tracking['height']
  n_x = $discrete_tracking['n_x']
  n_y = $discrete_tracking['n_y']
  t_x = $discrete_tracking['t_x']
  t_y = $discrete_tracking['t_y']

  if x != nil && y != nil && width != nil && height != nil && n_x != nil && n_y != nil && t_x != nil && t_y != nil
    tracking = {
        :x => x,
        :y => y,
        :width => width,
        :height => height,
        :n_x => n_x,
        :n_y => n_y,
        :t_x => t_x,
        :t_y => t_y
    }
    {:tracking => tracking}
  else
    {:tracking => {}}
  end
end)

# Routine that delete old proximity beacons

Thread.new do
  while true do
    baseStations = []

    for r in $resources.keys()
      resource = $resources[r]
      if resource['proximity'] != nil && resource['proximity']['timestamp'] != nil
        if Time.now.to_f - resource['proximity']['timestamp'] > 3.0
          if resource['proximity']['rid'] != nil
            baseStations.push(resource['proximity']['rid'])
            publishResourceExit(resource, resource['proximity']['rid'])
          end
          resource['proximity'] = {}
          $resources[r] = resource
          puts 'Delete proximity resource'
          publishResourceUpdate(resource)
        end
      end
    end

    # Update the counters of the base stations
    for baseStation in baseStations
      computeResourceUpdate(baseStation)
    end

    $cache.publish_update
    $cache.publish_enter
    $cache.publish_exit

    sleep 2
  end
end

puts 'Initialization completed'

# Just sit there waiting for messages to come
nutella.net.listen
