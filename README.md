# room-places-bot
This is the RoomPlaces bot that keeps track of resource position in 2D or 3D space.

In order to interact with this bot you can use the library Nutella client library using the methods described below:

## Publish - Subscribe channels

| Channel                               | Function                   | Direction         | Content                                        |
| ------------------------------------- | -------------------------- | ----------------- | ---------------------------------------------- |
| /location/resource/add                | Add a new resource         | client -> server  | {rid: '\<string\>', model: '\<model\>', type: '\<type\>'[, proximity_range: \<float\>]}  |
| /location/resource/remove             | Remove a resource          | client -> server  | {rid: '\<string\>'}                            |
| /location/resource/update             | Update a resource          | client -> server  | \<resource_update\>                            |
| /location/group/add                   | Add a group                | client -> server  | {group: '\<string\>'}                          |
| /location/group/remove                | Remove a group             | client -> server  | {group: '\<string\>'}                          |
| /location/group/resource/add          | Add resource to a group    | client -> server  | {rid: '\<string\>', group: '\<string\>'}       |
| /location/group/resource/remove       | Remove resource to a group | client -> server  | {rid: '\<string\>', group: '\<string\>'}       |
| /location/resources/added             | Publish added resources    | server -> client  | {resources: [\<resource\>*]}                   |
| /location/resources/removed           | Publish removed resources  | server -> client  | {resources: [\<resource\>*]}                   |
| /location/resources/updated           | Update a resource          | client -> server  | {resources: [\<resource_updated\>*]}           |
| /location/room/update                 | Update the room size       | client -> server  | {x: \<float\>, y: \<float\> [,z:\<float\>]}    |
| /location/room/updated                | Notify a room update       | server -> client  | {x: \<float\>, y: \<float\> [,z:\<float\>]}    |
| /location/resource/static/<rid>/enter | Notify resource enter area | server -> client  | {resources: ['\<string\>'*]}                   |
| /location/resource/static/<rid>/exit  | Notify resource exit area  | server -> client  | {resources: ['\<string\>'*]}                   |

\<type\> ::= STATIC | DYNAMIC 

\<model\> ::= IMAC | IPHONE | IPAD | IBEACON

## Request - Response channels

| Channel                               | Function                   | Request -> Response | Request       | Response                                   |
| ------------------------------------- | -------------------------- | ------------------- | ------------- | ------------------------------------------ |
| /location/resources                   | Request all the resources  | client -> server    | {}            | {resources: [\<resource\>*]}               |
| /location/estimote                    | Request all the iBeacons   | client -> server    | {}            | {resources: [\<resource_estimote\>*]}      |
| /location/room                        | Request the room size      | client -> server    | {}            | {x: \<float\>, y: \<float\> [,z:\<float\>]}|
| /location/resource/static/<rid>/inside| Notify resource enter area | server -> client    | {}            | {resources: ['\<string\>'*]}               |


\<resource\> ::= {rid: '\<string\>', model: '\<model\>', type: '\<type\>'}

\<resource_update\> ::= {rid: '\<string\>', (\<continuous\> | \<discrete\> | \<proximity\> | \<parameters\>)}

\<resource_updated\> ::= {rid: '\<string\>', model: '\<model\>', type: '\<type\>', (\<continuous\> | \<discrete\> | \<proximity\>), \<parameters_updated\> [, proximity_range: \<float\>]}

\<continuous\> ::= continuous: {x: \<float\>,  y: \<float\> [, z: \<float\>]}

\<discrete\> ::= discrete: {x: \<discrete_n\>,  y: \<discrete_n\> [, z: \<discrete_n\>]}

\<discrete_n\> ::= \<int\> | \<uppercase_char\>

\<proximity\> ::= proximity: {[rid: '', distance: '\<float\>']}

\<parameters\> ::= parameters: [\<parameter>*]

\<parameters_updated\> ::= parameters: {(\<key\>: '\<string\>')*}

\<parameter\> ::= {key: '\<string\>' , (value: '\<string\>' | delete: true)}


\<resource_estimote\> ::= {name: '\<string\>'}
