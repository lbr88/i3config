#!/bin/bash
#primary=CRT2
#secondary=DFP2
primary="DVI-0"
secondary="HDMI-0"
xrandr --output $primary --auto --right-of $secondary
xrandr --output $primary --primary
