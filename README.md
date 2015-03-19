# room-places-bot
This is the RoomPlaces bot that keeps track of resource position in 2D or 3D space.

In order to interact with this bot you can use the library Nutella client library using the methods described below:

## Publish - Subscribe channels

| Channel                         | Function                   | Direction         | Content                         |
| ------------------------------- | -------------------------- | ----------------- | ------------------------------- |
| /location/resource/add          | Add a new resource         | client -> server  | {rid: '', model: '\<model\>', type: '\<type\>'[, proximity_range: \<float\>]}  |
| /location/resource/remove       | Remove a resource          | client -> server  | {rid: ''}                            |
| /location/resource/update       | Update a resource          | client -> server  | \<resource_update\>                  |
| /location/group/add             | Add a group                | client -> server  | {group: ''}                          |
| /location/group/remove          | Remove a group             | client -> server  | {group: ''}                          |
| /location/group/resource/add    | Add resource to a group    | client -> server  | {rid: '', group: ''}                 |
| /location/group/resource/remove | Remove resource to a group | client -> server  | {rid: '', group: ''}                 |
| /location/resource/added        | Publish added resources    | server -> client  | {resources: [\<resource\>*]}         |
| /location/resource/removed      | Publish removed resources  | server -> client  | {resources: [\<resource\>*]}         |
| /location/resource/updated      | Update a resource          | client -> server  | {resources: [\<resource_updated\>*]} |
| /location/room/update           | Update the room size       | client -> server  | {x: \<float\>, y: \<float\> [,z:\<float\>]}|
| /location/room/updated          | Notify a room update       | server -> client  | {x: \<float\>, y: \<float\> [,z:\<float\>]}|

\<type\> ::= STATIC | DYNAMIC 

\<model\> ::= IMAC | IPHONE | IPAD | IBEACON

## Request - Response channels

| Channel                    | Function                  | Request -> Response | Request       | Response                              |
| -------------------------- | ------------------------- | ------------------- | ------------- | ------------------------------------- |
| /location/resources        | Request all the resources | client -> server    | {}            | {resources: [\<resource\>*]}          |
| /location/estimote         | Request all the iBeacons  | client -> server    | {}            | {resources: [\<resource_estimote\>*]} |
| /location/room             | Request the room size     | client -> server    | {}            | {x: \<float\>, y: \<float\> [,z:\<float\>]}|


\<resource\> ::= {rid: '', model: '\<model\>', type: '\<type\>'}

\<resource_update\> ::= {rid: '', (\<continuous\> | \<discrete\> | \<proximity\> | \<parameters\>)}

\<resource_updated\> ::= {rid: '', model: '\<model\>', type: '\<type\>', (\<continuous\> | \<discrete\> | \<proximity\>), \<parameters_updated\> [, proximity_range: \<float\>]}

\<continuous\> ::= continuous: {x: \<float\>,  y: \<float\> [, z: \<float\>]}

\<discrete\> ::= discrete: {x: \<discrete_n\>,  y: \<discrete_n\> [, z: \<discrete_n\>]}

\<discrete_n\> ::= \<int\> | \<uppercase_char\>

\<proximity\> ::= proximity: {rid: ''}

\<parameters\> ::= parameters: [\<parameter>*]

\<parameters_updated\> ::= parameters: {(\<key\>: '')*}

\<parameter\> ::= {key: '' , (value: '' | delete: true)}


\<resource_estimote\> ::= {name: ''}
