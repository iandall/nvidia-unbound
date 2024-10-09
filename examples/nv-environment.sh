#!/bin/sh

if [ -r /run/session-environment ]; then
  (
      . /run/session-environment
      [ -n "$NV_PATH" ] && {
	  PATH="$PATH:$NV_PATH"
	  ENVS=PATH
      }
      [ -n "$NV_LIBRARY_PATH" ] && {
	  LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}$NV_LIBRARY_PATH"
	  ENVS="$ENVS LD_LIBRARY_PATH"
      }
      dbus-update-activation-environment --systemd $ENVS
  )
fi
