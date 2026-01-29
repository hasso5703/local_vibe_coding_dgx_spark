#!/bin/bash

# ==========================================
# CONFIGURATION & CONSTANTES
# ==========================================
REMOTE_IP="100.114.54.60"
PORT="8025"
API_URL="http://$REMOTE_IP:$PORT/inference"
TEMP_FILE="/tmp/whisper_session.wav"

# Options Gradio-like
LANGS=("fr" "en" "de" "es" "it" "tr" "auto")
CUR_LANG_IDX=0 
DO_TRANSLATE=0 

# Couleurs & Tput
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
NC=$(tput sgr0)

# État
RECORDING_PID=0
IS_RECORDING=0

# ==========================================
# GESTION SYSTÈME
# ==========================================
cleanup() {
    tput cnorm
    [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
    if [[ $RECORDING_PID -ne 0 ]]; then kill -9 $RECORDING_PID 2>/dev/null; fi
    tput cup $(tput lines) 0
    echo -e "${BLUE}>>> Arrêt S2T.${NC}"
    exit 0
}
trap cleanup EXIT INT TERM

check_dependencies() {
    # On vérifie aussi grep et uname qui sont essentiels
    for dep in ffmpeg jq curl grep uname; do
        command -v "$dep" &> /dev/null || { echo "${RED}Erreur critique : Dépendance '$dep' manquante.${NC}"; exit 1; }
    done
}

configure_env() {
    OS_TYPE=$(uname -s)
    case "$OS_TYPE" in
        Darwin)
            # macOS
            DRIVER="avfoundation"
            # Index 0 est souvent le micro par défaut, mais ":0" suffit souvent pour "default"
            INPUT=":0" 
            CLIP_CMD="pbcopy"
            CHECK_CMD="ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | grep 'Audio'"
            ;;
        Linux)
            # Linux : Tentative PulseAudio sinon ALSA
            if pactl list sources &>/dev/null; then
                DRIVER="pulse"
                INPUT="default"
            else
                DRIVER="alsa"
                INPUT="sysdefault:CARD=0" # Fallback ALSA générique
            fi
            
            if command -v xclip &> /dev/null; then CLIP_CMD="xclip -sel clip"; else CLIP_CMD="wl-copy"; fi
            CHECK_CMD="ffmpeg -f $DRIVER -sources 2>&1 | grep -i 'input\|source' || arecord -l"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (via Git Bash)
            DRIVER="dshow"
            # Sur Windows, il faut souvent trouver le nom exact, mais "audio=Microphone..." est complexe.
            # On utilise une astuce : dshow permet parfois l'index audio=0 si config via liste.
            # Pour simplifier ici on garde une approche générique qui nécessite souvent le nom exact.
            # Solution robuste : scanner les devices (non implémenté pour simplicité absolue, on tente default)
            INPUT="audio=Microphone" 
            CLIP_CMD="cat > /dev/clipboard" # Fonctionne souvent sous Git Bash
            CHECK_CMD="ffmpeg -list_devices true -f dshow -i dummy 2>&1 | grep 'DirectShow audio devices'"
            ;;
        *)
            echo "${RED}OS non supporté : $OS_TYPE${NC}"
            exit 1
            ;;
    esac
}

check_hardware() {
    echo ">>> Vérification matériel ($OS_TYPE / $DRIVER)..."
    
    # Test FFmpeg installation réelle (version)
    if ! ffmpeg -version &> /dev/null; then
        echo "${RED}FFmpeg semble installé mais ne répond pas.${NC}"
        exit 1
    fi

    # Test Microphone (Simulation de listage)
    # Note : Sur macOS, cela peut déclencher la demande de permission la première fois.
    if ! eval "$CHECK_CMD" &> /dev/null; then
        echo "${YELLOW}ATTENTION : Aucun périphérique audio détecté via FFmpeg.$NC"
        echo "Si vous êtes sur macOS : Vérifiez Réglages Système > Confidentialité > Micro > Terminal."
        echo "Si vous êtes sur Linux : Vérifiez PulseAudio/ALSA."
        echo -n "Appuyez sur Entrée pour continuer malgré tout (ou Ctrl+C pour quitter)..."
        read
    fi
}

# ==========================================
# UI & AFFICHAGE
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
    echo -e " [ESPACE] : REC / STOP"
    echo -e " [L]      : Langue"
    echo -e " [T]      : Traduction (EN)"
    echo -e " [Q]      : Quitter"
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
    echo -e " STATUT : $1"
}

update_transcription() {
    tput cup 17 0; tput ed
    echo -e "${BOLD}RÉSULTAT :${NC}"
    echo -e "$1"
}

# ==========================================
# LOGIQUE MÉTIER
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
        # DÉMARRAGE
        IS_RECORDING=1
        update_status "${RED}${BOLD}● ENREGISTREMENT...${NC}"
        
        # Lancement ffmpeg
        ffmpeg -y -f "$DRIVER" -i "$INPUT" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_FILE" -loglevel quiet < /dev/null &
        RECORDING_PID=$!
        
        # Vérification immédiate : est-ce que ça a planté ?
        sleep 0.5
        if ! kill -0 $RECORDING_PID 2>/dev/null; then
            IS_RECORDING=0
            update_status "${RED}ERREUR : Impossible d'accéder au micro.${NC}"
            update_transcription "Vérifiez vos permissions ou le périphérique d'entrée ($INPUT)."
            return
        fi
    else
        # ARRÊT
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
    update_status "${YELLOW}Traitement...${NC}"

    local lang_arg=""
    local cur_lang="${LANGS[$CUR_LANG_IDX]}"
    if [[ "$cur_lang" != "auto" ]]; then
        lang_arg="-F language=$cur_lang"
    fi

    local trans_arg=""
    if [[ $DO_TRANSLATE -eq 1 ]]; then
        trans_arg="-F translate=true"
    fi

    # Appel API (curl gère les args vides proprement ici)
    RESPONSE=$(curl -s -F "file=@$TEMP_FILE" -F "temperature=0.0" -F "response_format=json" $lang_arg $trans_arg "$API_URL")
    
    # Nettoyage JSON brut (dépend de la réponse serveur, supposée standard OpenAI format)
    RESULT=$(echo "$RESPONSE" | jq -r '.text' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -n "$RESULT" && "$RESULT" != "null" ]]; then
        echo -n "$RESULT" | $CLIP_CMD
        update_status "${GREEN}PRÊT (Copié)${NC}"
        update_transcription "$RESULT"
    else
        update_status "${RED}Erreur API${NC}"
        update_transcription "$RESPONSE"
    fi
}

# ==========================================
# MAIN LOOP
# ==========================================
check_dependencies
configure_env
check_hardware # Vérification active du micro

# Check serveur
if ! curl -s --max-time 1 "$API_URL" >/dev/null; then true; fi

draw_ui
update_status "${GREEN}PRÊT${NC}"

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