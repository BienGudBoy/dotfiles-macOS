#!/bin/bash

# Get the current focused window information
WINDOW_INFO=$(yabai -m query --windows --window)
WINDOW_ID=$(echo "$WINDOW_INFO" | jq -r '.id')
IS_FLOATING=$(echo "$WINDOW_INFO" | jq -r '.["is-floating"]')
WINDOW_APP_NAME=$(echo "$WINDOW_INFO" | jq -r '.app')

# Get yabai rules
YABAI_RULES=$(yabai -m rule --list)

# Function to check if app has a rule and what the manage setting is
check_app_rule() {
    local app_name="$1"
    local rule_info
    
    # Look for exact match first, then check if app name matches regex patterns
    rule_info=$(echo "$YABAI_RULES" | jq -r --arg app "$app_name" '
        map(select(.app == $app)) | 
        if length > 0 then .[0] else 
            (map(select($app | test(.app))) | if length > 0 then .[0] else null end)
        end
    ')
    
    if [ "$rule_info" != "null" ]; then
        local manage_setting=$(echo "$rule_info" | jq -r '.manage')
        local rule_index=$(echo "$rule_info" | jq -r '.index')
        echo "$manage_setting:$rule_index"
    else
        echo "none:none"
    fi
}

# Function to save rule to yabairc configuration file
save_rule_to_yabairc() {
    local app_name="$1"
    local manage_setting="$2"  # "on" for tiled, "off" for floating
    local yabairc_path="$HOME/.config/yabai/yabairc-apprules"
    local rule_line="yabai -m rule --add app=\"^${app_name}$\" manage=${manage_setting}"
    
    echo "Saving rule to yabairc-apprules: $rule_line"
    
    # Check if yabairc exists
    if [ ! -f "$yabairc_path" ]; then
        echo "Warning: yabairc file not found at $yabairc_path"
        return 1
    fi
    
    # Create a backup
    cp "$yabairc_path" "${yabairc_path}.old"
    
    # Escape special characters in app name for regex patterns
    local app_escaped=$(printf '%s\n' "$app_name" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Search for existing rule for this app - look for any manage setting
    local existing_rule_pattern="yabai -m rule --add app=\"\^${app_escaped}\\\$\" manage="
    
    # Remove any existing rule for this app
    if grep -q "$existing_rule_pattern" "$yabairc_path"; then
        echo "Found existing rule for $app_name, removing it..."
        sed -i '' "/${existing_rule_pattern}/d" "$yabairc_path"
    else
        echo "No existing rule found for $app_name"
    fi
    
    # Only add a new rule if setting to manage=on (tiled)
    # For floating apps, we rely on the default behavior after removing any existing rule
    if [ "$manage_setting" = "on" ]; then
        local config_loaded_pattern="echo \"App rules loaded\.\""
        
        if grep -q "$config_loaded_pattern" "$yabairc_path"; then
            # Insert the rule before the config loaded line
            sed -i '' "/${config_loaded_pattern}/i\\
${rule_line}
" "$yabairc_path"
            echo "Rule added to yabairc successfully"
            osascript -e "display notification \"$app_name will be tiled!\" with title \"Yabai\""
        else
            # If the pattern is not found, append to the end of file
            echo "$rule_line" >> "$yabairc_path"
            echo "Rule appended to end of yabairc (config loaded line not found)"
        fi
    else
        echo "Rule removed from yabairc (app will use default floating behavior)"
        osascript -e "display notification \"$app_name will not be tiled!\" with title \"Yabai\""
    fi
}

# Check if the app has a rule
RULE_CHECK=$(check_app_rule "$WINDOW_APP_NAME")
MANAGE_SETTING=$(echo "$RULE_CHECK" | cut -d':' -f1)
RULE_INDEX=$(echo "$RULE_CHECK" | cut -d':' -f2)

echo "App: $WINDOW_APP_NAME"
echo "Currently floating: $IS_FLOATING"
echo "Rule manage setting: $MANAGE_SETTING"
echo "Rule index: $RULE_INDEX"

# Toggle logic
if [ "$IS_FLOATING" = "true" ]; then
    # Currently floating, make it tiled
    echo "Making window tiled..."
    yabai -m window --toggle float
    # Create a notification
    osascript -e "display notification \"Window is now tiled.\" with title \"Yabai\""
    # Save a rule in yabairc for tiled mode (add manage=on rule)
    save_rule_to_yabairc "$WINDOW_APP_NAME" "on"
    
    # If there's a rule that sets manage=false, update it to manage=true
    if [ "$MANAGE_SETTING" = "false" ] && [ "$RULE_INDEX" != "none" ]; then
        echo "Updating rule to manage=true..."
        yabai -m rule --remove "$RULE_INDEX"
        yabai -m rule --add app="^$WINDOW_APP_NAME$" manage=on
    fi
else
    # Currently tiled, make it floating
    echo "Making window floating..."
    yabai -m window --toggle float
    
    # Remove any existing rule from yabairc (falling back to default floating behavior)
    save_rule_to_yabairc "$WINDOW_APP_NAME" "remove"
fi