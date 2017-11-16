#!/bin/bash
#primary=CRT2
#secondary=DFP2

secondary="DP-2-1"
primary="eDP-1"
xrandr --output $primary --auto --right-of $secondary
xrandr --output $primary --primary
