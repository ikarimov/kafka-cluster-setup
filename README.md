#Kafka Cluster Setup
=================================================================================
```
NAME
	kafka_setup.sh - a simple script to setup Kafka cluster.

DESCRIPTION
	The script is to install and setup Kafka on Ubuntu, including Kafka daemon. 
	It supports a single-node and as well as multi-node cluster setup.

	The options are as follows:

    	-s    comma separated zookeeper server hostnames/IP addresses. The servers 
              making up the ZooKeeper ensemble.
    	-b    broker id and/or zookeeper myid. This is unique id (1-255) of each node
              in the cluster, default 1.
    	-v    kafka version (excludes Scala version), default 1.1.0
    	-t    setup type and the values can be:
                "kafka" - to setup Kafka only node
                "zookeeper" - to setup Zookeeper node
                "all" - to setup both Kafka and Zookeeper in a same node.
              By defaul "all" (both zookeeper and kafka) setup will be performed.
    	-d    comma separated list of directories under which to store Kafka log files.
    	-h    display this help.
```

### How to run the script
-------------------------
```
sudo ./kafka_setup.sh -v 1.1.0
```

###For help
------------
```
./kafka_setup.sh -h 
```

### Check Kafka and Zookeeper status
```
sudo service kafka status

sudo service zookeeper status
```

### About Kafka
---------------
For more info about Kafka and basic tutorial, please use https://kafka.apache.org/quickstart
