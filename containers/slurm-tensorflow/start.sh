#!/bin/bash

set -e

# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
    cmd=bash
else
    cmd=$*
fi

# Create Group
echo "Create Group: $NB_GROUP"
groupadd -g $NB_GID -f $NB_GROUP

# Create User
echo "Create User: $NB_USER"
useradd -d /home/$NB_USER -g $NB_GID -m -u $NB_UID $NB_USER

# Change to Home Dir
cd /home/$NB_USER

# Exec the command as NB_USER with the PATH and the rest of
# the environment preserved
echo "Executing the command: $cmd"
exec sudo -E -H -u $NB_USER PATH=$PATH PYTHONPATH=$PYTHONPATH $cmd
