#!/bin/sh
set -e

echo "USER_AUTH=$USER_AUTH"
echo "PASSWORD=$PASSWORD"
echo "BUILD=$BUILD"

ls /app/
ls /home/
whoami

sleep 10000