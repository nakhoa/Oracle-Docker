#!/bin/bash
scenario=$1
ORACLE_SID="myOracle"
CONTAINER_NAME="oracle-12.1.0.2"
IMAGE_NAME="oracle"
IMAGE_VERSION="12.1.0.2"
PRIVATE_DOCKER="anhkhoa-lap:18442"
ORACLE1_URL="http://anhkhoa-lap:8081/repository/maven-thirdparty/org/oracle/oracledb/12.1.0.2/oracledb-12.1.0.2-linuxamd64-1of2.zip"
ORACLE2_URL="http://anhkhoa-lap:8081/repository/maven-thirdparty/org/oracle/oracledb/12.1.0.2/oracledb-12.1.0.2-linuxamd64-2of2.zip"

#Please don't change value of INSTALL_FILE because it is used for Dockerfile
INSTALL_FILE_1="linuxamd64_12102_database_1of2.zip"
INSTALL_FILE_2="linuxamd64_12102_database_2of2.zip"
BACKUP_LOCATION="/home/builder/oracle/backup"
DATA_LOCATION="/home/builder/oracle/oradata"


if [ $# -ne 1 ]; then
    echo $0: usage: Enter Scenario to run
    exit 1
fi

echo $scenario

if [ "$scenario" == "build" ]; then #This scenario is used to build Oracle Image from dockerfile
	wget $ORACLE1_URL -O $INSTALL_FILE_1
	wget $ORACLE2_URL -O $INSTALL_FILE_2
	IMAGE_ID=$(docker build --force-rm=true --no-cache=true -t $IMAGE_NAME:$IMAGE_VERSION -f Dockerfile.ee .)
	if ["$IMAGE_ID" == ""]; then
		echo "Failed! Please fix it & build again"
		docker rmi $(docker images -f "dangling=true" -q)
		exit 1
	else
		echo "Build successfully"
	fi
elif [ "$scenario" == "run" ]; then #This scenario is used to run Oracle Image as container
	docker run -d -p 5500:5500 -p 1521:1521 -e ORACLE_SID=$ORACLE_SID --name $CONTAINER_NAME $IMAGE_NAME:$IMAGE_VERSION
elif [ "$scenario" == "deploy" ]; then #This scenario is used to deploy the Oracle Image to private docker server
	TIME_TAG=$(date +%s)
	docker tag $IMAGE_NAME:$IMAGE_VERSION $PRIVATE_DOCKER/$IMAGE_NAME:$IMAGE_VERSION-$TIME_TAG
	docker push $PRIVATE_DOCKER/$IMAGE_NAME:$IMAGE_VERSION-$TIME_TAG
	docker rmi $PRIVATE_DOCKER/$IMAGE_NAME:$IMAGE_VERSION-$TIME_TAG
elif [ "$scenario" == "clean" ]; then #This scenario delete the container
	docker rm -f $CONTAINER_NAME
elif [ "$scenario" == "stop" ]; then #This scenario stop the container
	docker stop $CONTAINER_NAME
elif [ "$scenario" == "delete" ]; then #This scenario delete the Oracle Image
	docker rmi $IMAGE_NAME:$IMAGE_VERSION
elif [ "$scenario" == "backup" ]; then
	TIME_TAG=$(date +%s)
	docker run --rm --name backup-data --volumes-from $CONTAINER_NAME -v $BACKUP_LOCATION:/home/oracle/backup $IMAGE_NAME:$IMAGE_VERSION tar cvf /home/oracle/backup/backup-$TIME_TAG.tar /opt/oracle/oradata
elif [ "$scenario" == "run-with-data" ]; then
	docker run -d -p 5500:5500 -p 1521:1521 -e ORACLE_SID=$ORACLE_SID -v $DATA_LOCATION:/opt/oracle/oradata --name $CONTAINER_NAME $IMAGE_NAME:$IMAGE_VERSION
else
    echo "Please enter the correct scenario"
	echo "    - build: to build docker image"
	echo "    - run: to run image as a container"
	echo "    - deploy: to push image to private registry"
	echo "    - clean: to clean the container"
	echo "    - stop: to stop the container"
	echo "	  - backup: backup the oracle data"
	echo "	  - run-with-data: run with exist data"
	echo "	  - delete: to delete the image"
fi
