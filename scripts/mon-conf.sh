#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [--left|--right] [--undock|--no-laptop] [--limit-resolution]"
    echo "  --left            Arrange additional monitors to the left of the primary display."
    echo "  --right           Arrange additional monitors to the right of the primary display."
    echo "  --undock          Turn off all external monitors and make eDP-1 the primary display."
    echo "  --no-laptop       Disable the laptop display (eDP-1) after enabling external displays."
    echo "  --limit-resolution Limit all displays to maximum 1440p resolution."
}

# Ensure xrandr and zenity are installed
if ! command -v xrandr &> /dev/null; then
    echo "Error: xrandr is not installed. Please install it and try again."
    exit 1
fi

if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed. Please install it and try again."
    exit 1
fi

# Parse arguments
mode=""
disable_laptop=false
force_limit_resolution=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --left|--right)
            if [[ -n "$mode" ]]; then
                echo "Error: Cannot specify both --left and --right at the same time."
                usage
                exit 1
            fi
            mode=${1#--}  # Strip the leading "--"
            ;;
        --undock)
            if [[ "$disable_laptop" == true ]]; then
                echo "Error: Cannot combine --undock and --no-laptop."
                usage
                exit 1
            fi
            mode="undock"
            ;;
        --no-laptop)
            disable_laptop=true
            ;;
        --limit-resolution)
            force_limit_resolution=true
            ;;
        *)
            echo "Error: Invalid argument '$1'"
            usage
            exit 1
            ;;
    esac
    shift
done

# If no primary mode is specified, exit
if [[ -z "$mode" ]]; then
    usage
    exit 1
fi

# Function for --undock mode
undock_mode() {
    primary_display="eDP-1"
    connected_monitors=$(xrandr --query | grep " connected" | awk '{ print $1 }')

    echo "Turning off all external monitors..."
    for monitor in $connected_monitors; do
        if [[ "$monitor" != "$primary_display" ]]; then
            xrandr --output "$monitor" --off
        fi
    done

    echo "Making $primary_display the primary display."
    primary_resolution=$(get_best_resolution "$primary_display")
    if [[ -n "$primary_resolution" ]]; then
        xrandr --output "$primary_display" --mode "$primary_resolution" --primary
    else
        xrandr --output "$primary_display" --auto --primary
    fi
    echo "Undock complete: All external monitors are off, and $primary_display is now primary."
    exit 0
}

# Handle --undock mode
if [[ "$mode" == "undock" ]]; then
    undock_mode
fi

# Detect connected monitors
connected_monitors=$(xrandr --query | grep " connected" | awk '{ print $1 }')

# Function to get best resolution (with optional 1440p limit)
get_best_resolution() {
    local monitor="$1"
    local limit_to_1440p="${2:-false}"
    local available_modes
    available_modes=$(xrandr --query | sed -n "/$monitor connected/,/^[^ ]/p" | grep -E "^\s+[0-9]+x[0-9]+" | awk '{print $1}')
    
    local best_resolution=""
    local max_pixels=999999999  # No limit by default
    local best_pixels=0
    
    # Set 1440p limit if requested
    if [[ "$limit_to_1440p" == "true" ]]; then
        max_pixels=3686400  # 2560x1440 = 3,686,400 pixels
    fi
    
    while IFS= read -r resolution; do
        if [[ -n "$resolution" ]]; then
            local width height pixels
            width=$(echo "$resolution" | cut -d'x' -f1)
            height=$(echo "$resolution" | cut -d'x' -f2)
            pixels=$((width * height))
            
            if [[ $pixels -le $max_pixels && $pixels -gt $best_pixels ]]; then
                best_resolution="$resolution"
                best_pixels=$pixels
            fi
        fi
    done <<< "$available_modes"
    
    echo "$best_resolution"
}

# Function to check if monitor has resolution higher than 1440p
has_resolution_above_1440p() {
    local monitor="$1"
    local available_modes
    available_modes=$(xrandr --query | sed -n "/$monitor connected/,/^[^ ]/p" | grep -E "^\s+[0-9]+x[0-9]+" | awk '{print $1}')
    
    local max_1440p_pixels=3686400  # 2560x1440 = 3,686,400 pixels
    
    while IFS= read -r resolution; do
        if [[ -n "$resolution" ]]; then
            local width height pixels
            width=$(echo "$resolution" | cut -d'x' -f1)
            height=$(echo "$resolution" | cut -d'x' -f2)
            pixels=$((width * height))
            
            if [[ $pixels -gt $max_1440p_pixels ]]; then
                return 0  # Found resolution above 1440p
            fi
        fi
    done <<< "$available_modes"
    
    return 1  # No resolution above 1440p found
}

# Define the primary monitor (eDP-1) and verify connectivity
primary_display="eDP-1"
if echo "$connected_monitors" | grep -q "^$primary_display$"; then
    echo "Primary display ($primary_display) is connected."
else
    echo "Primary display ($primary_display) not found. Exiting."
    exit 1
fi

# Filter out the primary monitor to get the additional monitors
mapfile -t additional_monitors < <(echo "$connected_monitors" | grep -v "^$primary_display$")

if [[ ${#additional_monitors[@]} -eq 0 ]]; then
    echo "No additional monitors detected. Exiting."
    exit 1
fi

# Check for high-resolution displays and ask user about limiting them
limit_resolution=false
high_res_monitors=()

# Check all connected monitors for resolutions above 1440p
all_monitors=("$primary_display" "${additional_monitors[@]}")
for monitor in "${all_monitors[@]}"; do
    if has_resolution_above_1440p "$monitor"; then
        high_res_monitors+=("$monitor")
    fi
done

# If --limit-resolution was specified, use it; otherwise ask user if high-res monitors are detected
if [[ "$force_limit_resolution" == true ]]; then
    limit_resolution=true
    echo "Resolution limiting forced via --limit-resolution parameter."
elif [[ ${#high_res_monitors[@]} -gt 0 ]]; then
    monitor_list=$(printf '%s, ' "${high_res_monitors[@]}")
    monitor_list=${monitor_list%, }  # Remove trailing comma and space
    
    if zenity --question --title="High Resolution Detected" \
        --text="The following monitor(s) support resolutions higher than 1440p:\n\n$monitor_list\n\nDo you want to limit them to 1440p maximum?" \
        --ok-label="Yes (Limit to 1440p)" --cancel-label="No (Use full resolution)"; then
        limit_resolution=true
        echo "Resolution will be limited to 1440p maximum."
    else
        echo "Using full resolution capabilities."
    fi
fi

# Configure the primary monitor
primary_resolution=$(get_best_resolution "$primary_display" "$limit_resolution")
if [[ -n "$primary_resolution" ]]; then
    xrandr --output "$primary_display" --primary --mode "$primary_resolution"
else
    xrandr --output "$primary_display" --primary --auto
fi

# Interactive monitor arrangement
echo "Setting up the monitors..."
current_position="--${mode}-of $primary_display"

for monitor in "${additional_monitors[@]}"; do
    echo "Placing $monitor $current_position"
    monitor_resolution=$(get_best_resolution "$monitor" "$limit_resolution")
    if [[ -n "$monitor_resolution" ]]; then
        xrandr --output "$monitor" --mode "$monitor_resolution" "$current_position"
    else
        xrandr --output "$monitor" --auto "$current_position"
    fi
    current_position="--${mode}-of $monitor"
done

echo "Monitors have been arranged in the following order:"
echo -e "$primary_display -> ${additional_monitors[*]} (${mode})"

# Handle confirmation and swapping logic
if ! zenity --question --title="Monitor Validation" \
    --text="Are the monitors shown in the correct order?\n\nOrder: $primary_display -> ${additional_monitors[*]}\n\nChoose Yes to confirm or No to rearrange." \
    --ok-label="Yes (Keep)" --cancel-label="No (Rearrange)"; then
    # Only consider external monitors for reordering logic
    external_monitors=("${additional_monitors[@]}")
    if [[ ${#external_monitors[@]} -eq 2 ]]; then
        echo "Auto-swapping the two external monitors..."
        primary_resolution=$(get_best_resolution "$primary_display" "$limit_resolution")
        if [[ -n "$primary_resolution" ]]; then
            xrandr --output "$primary_display" --mode "$primary_resolution" --primary
        else
            xrandr --output "$primary_display" --auto --primary
        fi
        
        monitor1_resolution=$(get_best_resolution "${external_monitors[1]}" "$limit_resolution")
        if [[ -n "$monitor1_resolution" ]]; then
            xrandr --output "${external_monitors[1]}" --mode "$monitor1_resolution" --"${mode}"-of "$primary_display"
        else
            xrandr --output "${external_monitors[1]}" --auto --"${mode}"-of "$primary_display"
        fi
        
        monitor0_resolution=$(get_best_resolution "${external_monitors[0]}" "$limit_resolution")
        if [[ -n "$monitor0_resolution" ]]; then
            xrandr --output "${external_monitors[0]}" --mode "$monitor0_resolution" --"${mode}"-of "${external_monitors[1]}"
        else
            xrandr --output "${external_monitors[0]}" --auto --"${mode}"-of "${external_monitors[1]}"
        fi
    else
        echo "Let's rearrange the monitors."

        input_order=$(zenity --entry --title="Rearrange Monitors" \
            --text="Enter the monitors in the correct order (space-separated, excluding $primary_display):" \
            --entry-text="${external_monitors[*]}")

        if [[ -z "$input_order" ]]; then
            echo "No input provided. Exiting."
            exit 1
        fi

        read -r -a new_order <<< "$input_order"

        # Validate if all external monitors are mentioned
        for monitor in "${external_monitors[@]}"; do
            if [[ ! " ${new_order[*]} " == *" $monitor "* ]]; then
                zenity --error --text="Error: Monitor $monitor is missing in the new order. Please try again."
                exit 1
            fi
        done

        # Apply the new arrangement
        echo "Rearranging monitors..."
        prev_monitor="$primary_display"
        for monitor in "${new_order[@]}"; do
            monitor_resolution=$(get_best_resolution "$monitor" "$limit_resolution")
            if [[ -n "$monitor_resolution" ]]; then
                xrandr --output "$monitor" --mode "$monitor_resolution" --"${mode}-of" "$prev_monitor"
            else
                xrandr --output "$monitor" --auto --"${mode}-of" "$prev_monitor"
            fi
            prev_monitor="$monitor"
        done
    fi
fi

# After validation, set the first additional monitor as primary
echo "Making ${additional_monitors[0]} the primary display."
xrandr --output "${additional_monitors[0]}" --primary

# Ask if user wants to disable laptop display (unless --no-laptop was already specified)
if [[ "$disable_laptop" != "true" ]]; then
    if zenity --question --title="Laptop Display" \
        --text="Do you want to disable the laptop display (eDP-1)?" \
        --ok-label="Yes (Disable)" --cancel-label="No (Keep)"; then
        disable_laptop=true
    fi
fi

# Handle laptop display disabling
if [[ "$disable_laptop" == true ]]; then
    echo "Disabling the laptop display (eDP-1)..."
    xrandr --output "$primary_display" --off
    echo "Laptop display (eDP-1) has been disabled. Configuration complete."
fi

echo "Monitor configuration complete."
exit 0

