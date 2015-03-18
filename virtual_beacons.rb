require 'nutella_lib'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

# Parse command line arguments
run_id, broker = nutella.parse_args ARGV

baseStationRid = 'iPad1'
beaconRid = 'beacon1'

# Extract the component_id
component_id = nutella.extract_component_id

# Initialize nutella
nutella.init( run_id, broker, component_id)


puts 'Virtual beacon initialization'

# Publish an updated resource
def publishResourceUpdate(baseStationRid, beaconRid, distance)
	if(rand(0...100) > 80)
		nutella.net.publish('location/resource/update', {
	    		'rid' => beaconRid,
	    		'proximity' => {
	    			'rid' => baseStationRid,
	    			'distance' => distance
	    		}
	    	})
	end
end


# Routine that delete old proximity beacons
Thread.new do
  while true do
  	puts ">>>"
    publishResourceUpdate("iPad1", "beacon1", 1.0);
    publishResourceUpdate("iPad1", "vb1", 1.0);
    publishResourceUpdate("iPad1", "vb2", 1.1);
    publishResourceUpdate("iPad1", "vb3", 1.2);
    publishResourceUpdate("iPad1", "vb4", 1.3);
    publishResourceUpdate("iPad1", "vb5", 1.4);
    publishResourceUpdate("iPad1", "vb6", 1.5);
    publishResourceUpdate("iPad1", "vb7", 1.6);
    publishResourceUpdate("iPad1", "vb8", 1.7);
    publishResourceUpdate("iPad1", "vb9", 1.8);
    sleep 1
  end
end

puts "Initialization completed"

# Just sit there waiting for messages to come
nutella.net.listen
