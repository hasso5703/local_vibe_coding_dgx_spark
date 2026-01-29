#!/bin/bash

# ==========================================
# CONFIGURATION & CONSTANTS
# ==========================================
REMOTE_IP="100.114.54.60"
PORT="8025"
API_URL="http://$REMOTE_IP:$PORT/inference"
TEMP_FILE="/tmp/whisper_session.wav"

# Gradio-like Options
LANGS=("fr" "en" "de" "es" "it" "tr" "auto")
CUR_LANG_IDX=0 
DO_TRANSLATE=0 

# Colors & Tput
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
NC=$(tput sgr0)

# State
RECORDING_PID=0
IS_RECORDING=0

# ==========================================
# SYSTEM MANAGEMENT
# ==========================================
cleanup() {
    tput cnorm
    [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
    if [[ $RECORDING_PID -ne 0 ]]; then kill -9 $RECORDING_PID 2>/dev/null; fi
    tput cup $(tput lines) 0
    echo -e "${BLUE}>>> Stopping S2T.${NC}"
    exit 0
}
trap cleanup EXIT INT TERM

check_dependencies() {
    # Check grep and uname as well since they are essential
    for dep in ffmpeg jq curl grep uname; do
        command -v "$dep" &> /dev/null || { echo "${RED}Critical Error: Missing dependency '$dep'.${NC}"; exit 1; }
    done
}

configure_env() {
    OS_TYPE=$(uname -s)
    case "$OS_TYPE" in
        Darwin)
            # macOS
            DRIVER="avfoundation"
            # Index 0 is often the default mic, but ":0" is often enough for "default"
            INPUT=":0" 
            CLIP_CMD="pbcopy"
            CHECK_CMD="ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | grep 'Audio'"
            ;;
        Linux)
            # Linux: Attempt PulseAudio else ALSA
            if pactl list sources &>/dev/null; then
                DRIVER="pulse"
                INPUT="default"
            else
                DRIVER="alsa"
                INPUT="sysdefault:CARD=0" # Generic ALSA fallback
            fi
            
            if command -v xclip &> /dev/null; then CLIP_CMD="xclip -sel clip"; else CLIP_CMD="wl-copy"; fi
            CHECK_CMD="ffmpeg -f $DRIVER -sources 2>&1 | grep -i 'input\|source' || arecord -l"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (via Git Bash)
            DRIVER="dshow"
            # On Windows, exact name is often needed, but "audio=Microphone..." is complex.
            # Using a trick: dshow sometimes allows index audio=0 if config via list.
            # To simplify here we keep a generic approach that often requires the exact name.
            # Robust solution: scan devices (not implemented for absolute simplicity, attempting default)
            INPUT="audio=Microphone" 
            CLIP_CMD="cat > /dev/clipboard" # Often works under Git Bash
            CHECK_CMD="ffmpeg -list_devices true -f dshow -i dummy 2>&1 | grep 'DirectShow audio devices'"
            ;;
        *)
            echo "${RED}Unsupported OS: $OS_TYPE${NC}"
            exit 1
            ;;
    esac
}

check_hardware() {
    echo ">>> Checking hardware ($OS_TYPE / $DRIVER)..."
    
    # Test actual FFmpeg installation (version)
    if ! ffmpeg -version &> /dev/null; then
        echo "${RED}FFmpeg seems installed but is not responding.${NC}"
        exit 1
    fi

    # Test Microphone (Listing simulation)
    # Note: On macOS, this triggers permission request on first run.
    if ! eval "$CHECK_CMD" &> /dev/null; then
        echo "${YELLOW}WARNING: No audio device detected via FFmpeg.$NC"
        echo "If on macOS: Check System Settings > Privacy > Microphone > Terminal."
        echo "If on Linux: Check PulseAudio/ALSA."
        echo -n "Press Enter to continue anyway (or Ctrl+C to quit)..."
        read
    fi
}

# ==========================================
# UI & DISPLAY
# ==========================================
draw_ui() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "  ██████  ██████  ████████ "
    echo "  ██      ░░  ██  ░░░██░░░ "
    echo "  ░██████  ██████    ██    "
    echo "  ░░░░░██ ██░░░░     ██    "
    echo "  ██████  ████████   ██    "
    echo -e "  ░░░░░░  ░░░░░░░░   ░░    ${NC}"
    echo "----------------------------------------"
    echo -e " SERVER: ${BOLD}$REMOTE_IP${NC} | OS: ${BOLD}$OS_TYPE ($DRIVER)${NC}"
    echo "----------------------------------------"
    echo -e " [SPACE]  : REC / STOP"
    echo -e " [L]      : Language"
    echo -e " [T]      : Translation (EN)"
    echo -e " [Q]      : Quit"
    echo "----------------------------------------"
    tput civis
    draw_settings
}

draw_settings() {
    local raw_lang="${LANGS[$CUR_LANG_IDX]}"
    local lang_display=$(echo "$raw_lang" | tr '[:lower:]' '[:upper:]')
    
    local trans_str="OFF"
    local trans_color="$NC"
    
    if [[ $DO_TRANSLATE -eq 1 ]]; then 
        trans_str="ON (-> EN)"; trans_color="$CYAN"
    fi

    tput cup 13 0; tput el
    echo -e " CONFIG : LANG=[${GREEN}${lang_display}${NC}]  TRANS=[${trans_color}${trans_str}${NC}]"
}

update_status() {
    tput cup 15 0; tput el
    echo -e " STATUS : $1"
}

update_transcription() {
    tput cup 17 0; tput ed
    echo -e "${BOLD}RESULT :${NC}"
    echo -e "$1"
}

# ==========================================
# BUSINESS LOGIC
# ==========================================
cycle_lang() {
    local size=${#LANGS[@]}
    CUR_LANG_IDX=$(( (CUR_LANG_IDX + 1) % size ))
    draw_settings
}

toggle_trans() {
    DO_TRANSLATE=$((1 - DO_TRANSLATE))
    draw_settings
}

toggle_record() {
    if [[ $IS_RECORDING -eq 0 ]]; then
        # START
        IS_RECORDING=1
        update_status "${RED}${BOLD}● RECORDING...${NC}"
        
        # Start ffmpeg
        ffmpeg -y -f "$DRIVER" -i "$INPUT" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_FILE" -loglevel quiet < /dev/null &
        RECORDING_PID=$!
        
        # Immediate check: did it crash?
        sleep 0.5
        if ! kill -0 $RECORDING_PID 2>/dev/null; then
            IS_RECORDING=0
            update_status "${RED}ERROR: Cannot access microphone.${NC}"
            update_transcription "Check permissions or input device ($INPUT)."
            return
        fi
    else
        # STOP
        IS_RECORDING=0
        if [[ $RECORDING_PID -ne 0 ]]; then 
            kill $RECORDING_PID 2>/dev/null
            wait $RECORDING_PID 2>/dev/null
        fi
        process_audio
    fi
}

process_audio() {
    if [[ ! -f "$TEMP_FILE" ]]; then return; fi
    update_status "${YELLOW}Processing...${NC}"

    local lang_arg=""
    local cur_lang="${LANGS[$CUR_LANG_IDX]}"
    if [[ "$cur_lang" != "auto" ]]; then
        lang_arg="-F language=$cur_lang"
    fi

    local trans_arg=""
    if [[ $DO_TRANSLATE -eq 1 ]]; then
        trans_arg="-F translate=true"
    fi

    # API Call (curl handles empty args cleanly here)
    RESPONSE=$(curl -s -F "file=@$TEMP_FILE" -F "temperature=0.0" -F "response_format=json" $lang_arg $trans_arg "$API_URL")
    
    # Raw JSON cleanup (depends on server response, assumed standard OpenAI format)
    RESULT=$(echo "$RESPONSE" | jq -r '.text' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -n "$RESULT" && "$RESULT" != "null" ]]; then
        echo -n "$RESULT" | $CLIP_CMD
        update_status "${GREEN}READY (Copied)${NC}"
        update_transcription "$RESULT"
    else
        update_status "${RED}API Error${NC}"
        update_transcription "$RESPONSE"
    fi
}

# ==========================================
# MAIN LOOP
# ==========================================
check_dependencies
configure_env
check_hardware # Active microphone check

# Server check
if ! curl -s --max-time 1 "$API_URL" >/dev/null; then true; fi

draw_ui
update_status "${GREEN}READY${NC}"

while true; do
    IFS= read -rsn1 -p "" key
    
    if [[ "$key" == " " || "$key" == "" ]]; then
        toggle_record
    elif [[ "$key" == "l" || "$key" == "L" ]]; then
        cycle_lang
    elif [[ "$key" == "t" || "$key" == "T" ]]; then
        toggle_trans
    elif [[ "$key" == "q" || "$key" == "Q" ]]; then
        cleanup
    fi
done