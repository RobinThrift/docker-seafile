#!/bin/bash

while :
do
	echo -en "READY\n"
	read line
	kill $(cat /tmp/supervisord.pid)
	echo -en "RESULT 2\nOK"
done
