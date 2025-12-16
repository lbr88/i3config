#!/bin/bash
_term() { 
  echo "Caught SIGTERM signal exiting!"
  rm $pidfile
  exit 0
}
trap _term SIGTERM
_run() {
    # fork the process
    nohup jigglejiggle.sh run &> /dev/null &
    pid=$!
    # write the pid to the pidfile
    echo $pid > $pidfile
    notify-send -t 1000 -a "jiggle" "jiggle: on"
}
pidfile=~/.local/run/jigglejiggle.pid
if ! [ -d "$(dirname $pidfile)" ];then
  mkdir -p "$(dirname $pidfile)"
fi
if [ "$1" = "run" ]; then
  while true; do
    xdotool mousemove_relative --sync 1 1
    xdotool mousemove_relative --sync -- -1 -1
  sleep 1
  done
  rm $pidfile
  exit 0
fi

# check if the pidfile already exists
if [ -f $pidfile ]; then
  # if it does, read the pid from the file
  pid=$(cat $pidfile)
  # check if the process is still running
  if ps -p "$pid" > /dev/null; then
    rm $pidfile
    kill "$pid"
    notify-send -t 1000 -a "jiggle" "jiggle: off"
  else
    _run
  fi
else
  _run
fi
