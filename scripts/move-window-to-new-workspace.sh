#!/bin/bash
newspace=$(($(i3-msg -t get_workspaces | tr , '\n' | grep '"num":' | cut -d : -f 2 | sort -rn | head -1) + 1))
i3-msg move container to workspace $newspace;
i3-msg workspace $newspace
