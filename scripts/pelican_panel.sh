#!/bin/sh
set -e

echo "USER_AUTH=$USER_AUTH"
echo "PASSWORD=$PASSWORD"
echo "BUILD=$BUILD"

sh start_update.sh

sleep 10000