#!/bin/bash

# Directory where this script is located
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Helper to find app in standard locations
find_app() {
    local app_name="$1"
    if [ -d "/Applications/${app_name}" ]; then
        echo "/Applications/${app_name}"
    elif [ -d "${HOME}/Applications/${app_name}" ]; then
        echo "${HOME}/Applications/${app_name}"
    elif [ -d "${DIR}/${app_name}" ]; then
        echo "${DIR}/${app_name}"
    fi
}

# Determine which app to use
if [ "$KMPARAM_Persistant" != "0" ]; then
    NotifiPath=$(find_app "NotifiCLI.app")
    if [ -n "$NotifiPath" ]; then
        App="${NotifiPath}/Contents/Apps/NotifiPersistent.app/Contents/MacOS/NotifiPersistent"
    else
        echo "Error: NotifiCLI.app not found in Applications or Action folder." >&2
        exit 1
    fi
else
    NotifiPath=$(find_app "NotifiCLI.app")
    if [ -n "$NotifiPath" ]; then
        App="${NotifiPath}/Contents/MacOS/NotifiCLI"
    else
        echo "Error: NotifiCLI.app not found in Applications or Action folder." >&2
        exit 1
    fi
fi

# Check for other parameters and construct flags
ActionsFlag=""
if [ -n "$KMPARAM_Actions" ]; then
    ActionsFlag="-actions"
fi

ReplyFlag=""
ReplyPlaceholder=""
if [ -n "$KMPARAM_Reply_Placeholder" ]; then
    ReplyFlag="-reply"
    ReplyPlaceholder="$KMPARAM_Reply_Placeholder"
fi

URLFlag=""
URLValue=""
if [ -n "$KMPARAM_URL" ]; then
    URLFlag="-url"
    URLValue="$KMPARAM_URL"
fi

SoundFlag=""
SoundName=""
if [ -n "$KMPARAM_Sound" ]; then
    SoundFlag="-sound"
    SoundName="$KMPARAM_Sound"
fi

IconFlag=""
IconPath=""
if [ -n "$KMPARAM_Icon_Path" ]; then
    IconFlag="-icon"
    IconPath="$KMPARAM_Icon_Path"
fi

ImageFlag=""
ImagePath=""
if [ -n "$KMPARAM_Image_Path" ]; then
    ImageFlag="-image"
    ImagePath="$KMPARAM_Image_Path"
fi

"$App" \
  -title "${KMPARAM_Title}" \
  -subtitle "${KMPARAM_Subtitle}" \
  -message "${KMPARAM_Message}" \
  $ActionsFlag "${KMPARAM_Actions}" \
  $ReplyFlag "$ReplyPlaceholder" \
  $URLFlag "$URLValue" \
  $SoundFlag "$SoundName" \
  $IconFlag "$IconPath" \
  $ImageFlag "$ImagePath"
