# room-places-bot
This is the RoomPlaces bot that keeps track of resource position in 2D or 3D space.

In order to interact with this bot you can use the library Nutella client library using the methods described below:

## Publish - Subscribe channels

| Channel                         | Function                   | Direction         | Content                         |
| ------------------------------- | -------------------------- | ----------------- | ------------------------------- |
| /location/resource/add          | Add a new resource         | client -> server  | {rid: '', model: '\<model\>', type: '\<type\>'}  |
| /location/resource/remove       | Remove a resource          | client -> server  | {rid: ''}                           |
| /location/resource/update       | Update a resource          | client -> server  | \<resource_update\>                 |
| /location/group/add             | Add a group                | client -> server  | {group: ''}                         |
| /location/group/remove          | Remove a group             | client -> server  | {group: ''}                         |
| /location/group/resource/add    | Add resource to a group    | client -> server  | {rid: '', group: ''}                |
| /location/group/resource/remove | Remove resource to a group | client -> server  | {rid: '', group: ''}                |
| /location/resource/added        | Publish added resources    | server -> client  | {resources: [\<resource\>*]}        |
| /location/resource/removed      | Publish removed resources  | server -> client  | {resources: [\<resource\>*]}        |
| /location/resource/updated      | Update a resource          | client -> server  | {resources: [\<resource_update\>*]} |

\<type\> ::= STATIC | DYNAMIC 

\<model\> ::= IMAC | IPHONE | IPAD | IBEACON

## Request - Response channels

| Channel                    | Function                  | Request -> Response | Request       | Response                              |
| -------------------------- | ------------------------- | ------------------- | ------------- | ------------------------------------- |
| /location/resources        | Request all the resources | client -> server    | {}            | {resources: [\<resource\>*]}          |
| /location/estimote         | Request all the iBeacons  | client -> server    | {}            | {resources: [\<resource_estimote\>*]} |


\<resource\> ::= {rid: '', model: '\<model\>', type: '\<type\>'}

\<resource_update\> ::= {rid: '', (\<continuous\>|\<discrete\>|\<proximity\>)}

\<continuous\> ::= continuous: {x: '',  y: '', z: ''}

\<discrete\> ::= discrete: {x: '',  y: '', z: ''}

\<proximity\> ::= proximity: {\<resource_update\>}

\<resource_estimote\> ::= {name: ''}
