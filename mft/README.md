
# Configure

To prepare functions for work set server, username, and passowrd in the environemnt.

```
mftserver=http://mft.acme.com
mftauth=mftuser:welcome1
```

By default scripts will save data in current dir. Yu may specify own directory to store data files.

```
mftlog=~/mft/logs
```

Register function in current shell session.

```
. status.sh
```


# Fetch status from MFT server

This function gets data over HTTP from MFT instance. This call is required for other functions to work with latest data.

```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
fetchMFTEventStatus $eventId
```

Event state is written in three files with high, medium, and low level status.

# Display fetched data

Get status with state machine adjusted to real situation. DONE is changed to DOWNLOADED or FAILED depending on values of active and failed counters.


```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
getEventStatus $eventId
```

```
{
    "activeInstanceCount": "0",
    "completedInstanceCount": "283",
    "failedInstanceCount": "0",
    "status": "DONE"
}
```

Get files in transit.

```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
getMFTActiveStatus $eventId
```

Get complete status in CSV format.

```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
getMFTStatusCSV $eventId
```

```
2020-03-15,21:47:53,+0100,1584305273,1465CAD9-8400-4FC7-9725-E783F03627C4,0,283,0,DONE,885_0000636_2020_03_15.csv,COMPLETED,SUCCESSFUL,89221,COMPLETED,SUCCESSFUL,89221
2020-03-15,21:47:53,+0100,1584305273,1465CAD9-8400-4FC7-9725-E783F03627C4,0,283,0,DONE,709_0000636_2020_03_15.csv,COMPLETED,SUCCESSFUL,18202204,COMPLETED,SUCCESSFUL,18202204
2020-03-15,21:47:53,+0100,1584305273,1465CAD9-8400-4FC7-9725-E783F03627C4,0,283,0,DONE,608_0000636_2020_03_15.csv,COMPLETED,SUCCESSFUL,43778934,COMPLETED,SUCCESSFUL,43778934
(...)
```

# Active 

Avtive status works in loop until status of the event is returned as DONE or FAILED. Status is written in status.log csv file with all information from high and low level status data structures. Note that Target details describes only first Target.

```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
activeMFTStatus $eventId
```

Saves data in $mftlog/$eventId/status.log file.

```
tail -1 $mftlog/$eventId/status.log

2020-03-15,21:47:53,+0100,1584305273,1465CAD9-8400-4FC7-9725-E783F03627C4,0,283,0,DONE,inv_position_MENA_nf_SAU_HEN_722_0000636_2020_03_15.csv,COMPLETED,SUCCESSFUL,38228526,COMPLETED,SUCCESSFUL,38228526
```


# MFT status (out of the box)

Check status with logical errors as defined by MFT. The problem is that status is returned as DONE even when there are active transport sessions to Target or some instances has failed. Thsi function has no business value, and is added to present current MFT behavior.

```
eventId=1465CAD9-8400-4FC7-9725-E783F03627C4
getMFTCurrentStatus $eventId
```
```
{
  "activeInstanceCount": "0",
  "completedInstanceCount": "283",
  "failedInstanceCount": "0",
  "status": "DONE"
}
```

