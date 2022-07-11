#!/bin/sh

if [ -z "$root" ] ; then
  root=iguanaboot
fi

rootok=1

# Handle command line options
# should be rd.iguana.$

export CONTAINERS=($getarg rd.iguana.containers)
export CONTROL_URL=($getarg rd.iguana.control_url)