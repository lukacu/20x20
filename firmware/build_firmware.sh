#!/bin/bash

# If NODEMCU_FIRMWARE_SOURCE is not set, only run if it is provided as an argument
if [ -z "$NODEMCU_FIRMWARE_SOURCE" ]; then
  if [ -z "$1" ]; then
    echo "Please provide the path to the nodemcu-firmware source directory"
    exit 1
  fi
  NODEMCU_FIRMWARE_SOURCE=$1
fi

# Get current directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy firmware changes to the firmware source
cp $DIR/user_modules.h $NODEMCU_FIRMWARE_SOURCE/app/include/
cp $DIR/pixmod.c $NODEMCU_FIRMWARE_SOURCE/app/modules/

docker run --rm -ti -v $NODEMCU_FIRMWARE_SOURCE:/opt/nodemcu-firmware marcelstoer/nodemcu-build build
