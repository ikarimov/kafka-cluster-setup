#!/bin/bash
##############################################################################
# A simple script to setup Kafka cluster
##############################################################################
# MIT License
#   
# Copyright (c) 2018 Ihvol
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###############################################################################

#PARAMETERS
kafka_path="/opt/kafka"					# Kafka installation path
srv_file="kafka.service"				# Kafka daemon service file
srv_path="/etc/systemd/system/$srv_file"		# Kafka daemon service file path
kafka_cfg="$kafka_path/config/server.properties"	# Kafka configuration file
zoo_cfg="/etc/zookeeper/conf/zoo.cfg"			# zookeeper configuration
myid="/etc/zookeeper/conf/myid"			
local_machine=`hostname -I | xargs`
servers="$local_machine"				# cluster nodes, comma separated
bid=1							# broker id/myid, cluster-unique instance id (1-255)
version="1.1.0"						# kafka version, excludes Scala version
scala_ver="2.11"
setup_type=0
log_dirs="/tmp/kafka-logs"
force=0


say(){
    echo
    echo "$1"
    echo
}

update(){
    say "Updating the system package list..."
    apt-get update
    #apt-get -f install
}


show_help()
{
cat << EOF
NAME 
     $0 -- install and setup Kafka cluster on Ubuntu

SYNOPSIS
     $0 [-sbvtdh]

DESCRIPTION:
        The script is to install and setup Kafka on Ubuntu, including Kafka daemon.
        It supports a single-node and as well as multi-node cluster setup.

        The options are as follows:

        -s    comma separated zookeeper server hostnames/IP addresses. The servers
              making up the ZooKeeper ensemble.

        -b    broker id and/or zookeeper myid. This is unique id (1-255) of each node
              in the cluster, default 1.

        -v    kafka version (excludes Scala version), e.g. 1.1.0

        -t    setup type and the values can be:

                "kafka" - to setup Kafka only node
                "zookeeper" - to setup Zookeeper node
                "all" - to setup both Kafka and Zookeeper in a same node.

              By defaul "all" (both zookeeper and kafka) setup will be performed.

        -d    comma separated list of directories under which to store Kafka log files.

        -h    display this help.
EOF
}


while getopts ":s:b:v:t:d:h" opt; do
  #echo "Option $opt set with value ${OPTARG}"
  case ${opt} in
    s)
      servers=${OPTARG}
      ;;
    b)
      bid=${OPTARG}
      ;;
    v)
      version=${OPTARG}
      ;;
    t)
      setup_type=${OPTARG}
      ;;
    d)
      log_dirs=${OPTARG}
      ;;
    h)
      show_help
      exit 2
      ;;
    \? ) echo "Usage: cmd [-h] [-t]"
      ;;
  esac
done


amiroot(){
    if [ "$EUID" != 0 ]; then
      say "Please run this script as root or using sudo!"
      exit 3
    fi
}


setup_zookeeper(){

    say "Installing zookeeper..."
    if [ $(dpkg-query -W -f='${Status}' zookeeper 2>/dev/null | grep -c "ok installed") -ne 0 ];
    then
      apt-get remove -y --autoremove zookeeper
    fi
    apt-get install -y zookeeperd
    say "Configuring zookeeper..."
    if [ ! -e $zoo_cfg ]; then
        cat << EOF > $zoo_cfg
        # The number of milliseconds of each tick
        tickTime=2000
        # The number of ticks that the initial 
        # synchronization phase can take
        initLimit=10
        # The number of ticks that can pass between 
        # sending a request and getting an acknowledgement
        syncLimit=5
        # the directory where the snapshot is stored.
        dataDir=/var/lib/zookeeper
        # Place the dataLogDir to a separate physical disc for better performance
        # dataLogDir=/disk2/zookeeper
        
        # the port at which the clients will connect
        clientPort=2181
EOF
    fi
    sed -i '/^server./d' $zoo_cfg
    sid=0
    for i in $(echo $servers | sed "s/,/ /g")
    do
        sid=$(expr $sid + 1)
        sed -r -i "/^server.$sid=/{h;s/=.*/=$i:2888:3888/};\${x;/^$/{s//server.$sid=$i:2888:3888/;H};x}" $zoo_cfg
        if [ "$localhostname" == "$i" ]
        then
            bid=$sid
        fi
    done

    say "Configuring myid file..."
    echo $bid > $myid
}


setup_kafka(){

    say "Installing Kafka $version ..."
    if [ -d "$kafka_path" ];
    then
        say "Removing existing Apache Kafka..."
        systemctl stop kafka
        rm -rf $kafka_path
        # clean up old log folder if needed, specially if broker id is changed
        #rm -rf /tmp/kafka-logs
    fi
    say "downloading Kafka..."
    pkg_file="kafka_${scala_ver}-${version}.tgz"
    wget http://mirror.cogentco.com/pub/apache/kafka/$version/$pkg_file
    
    mkdir -p $kafka_path
    
    say "extracting kafka package..."
    tar -xzf $pkg_file --strip-components=1 -C $kafka_path
    rm -rf $pkg_file

    say "configuring kafka cluster..."
    hosts=$(echo $servers | sed -E 's/([^,]+)/\1:2181/g')
    sed -r -i "/^zookeeper.connect=/{h;s/=.*/=$hosts/};\${x;/^$/{s//zookeeper.connect=$hosts/;H};x}" $kafka_cfg 
    sed -r -i "/^broker.id=/{h;s/=.*/=$bid/};\${x;/^$/{s//broker.id=$bid/;H};x}" $kafka_cfg 
    sed -i "s|^log.dirs=.*|log.dirs=$log_dirs|g" $kafka_cfg
    
    say "configuring kafka daemon service..."
    if ! [ -e $srv_path ]
    then
        cp $srv_file $srv_path
        systemctl daemon-reload
    fi
    
    say "Starting Apache Kafka..."
    service kafka restart
}

setup_java(){

    say "checking Java..."
    which java || apt-get --assume-yes install default-jre
    #java -version
}


setup(){
    amiroot
    update
    setup_java
    if [ $setup_type = "kafka" ]; then
        setup_kafka    
    elif [ $setup_type = "zookeeper" ]; then
        setup_zookeeper
        say "You may need to restart your Kafka services!"
    else
        setup_zookeeper
        setup_kafka    
    fi
}

setup
