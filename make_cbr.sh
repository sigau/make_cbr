#!/bin/bash

# === PARAMÈTRES ===
POSITIONAL_ARGS=()
DRY_RUN=false
LOG_FILE=""
TEMP_DIR="./temp_extract"

# === COULEURS ===
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

# === OPTIONS ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        -*|--*)
            echo -e "${RED}❌ Option inconnue : $1${NC}"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# === PARAMÈTRES POSITIONNELS ===
SOURCE_DIR="${POSITIONAL_ARGS[0]}"
OUTPUT_FILE="${POSITIONAL_ARGS[1]}"

if [[ -z "$SOURCE_DIR" || -z "$OUTPUT_FILE" ]]; then
    echo -e "${YELLOW}Usage : $0 [--dry-run] [--log log.txt] <dossier_source> <fichier_sortie.cbr>${NC}"
    exit 1
fi

# === VÉRIF DES DÉPENDANCES ===
for cmd in unzip rar; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ Erreur : '$cmd' n'est pas installé.${NC}"
        exit 1
    fi
done

# === LOGGING ===
log() {
    echo -e "$1"
    [[ -n "$LOG_FILE" ]] && echo -e "$(date '+%F %T') $1" >> "$LOG_FILE"
}

# === DÉMARRAGE ===
log "${YELLOW}📁 Source : $SOURCE_DIR"
log "📦 Fichier final : $OUTPUT_FILE"
$DRY_RUN && log "${YELLOW}🧪 Mode simulation activé (--dry-run)${NC}"

# === PRÉPARATION DOSSIER TEMP ===
[[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

i=1

cd "$SOURCE_DIR" || { echo -e "${RED}❌ Dossier source introuvable.${NC}"; exit 1; }

find . -type f \( -iname "*.cbz" -o -iname "*.cbr" \) | sort | while read -r file; do
    ext="${file##*.}"
    base="$(basename "${file%.*}")"
    padded_i=$(printf "%03d" "$i")
    target_dir="$TEMP_DIR/${padded_i}_${base}"

    log "${GREEN}➕ Fichier trouvé : $file → $target_dir${NC}"

    if ! $DRY_RUN; then
        mkdir -p "$target_dir"
        if [[ "$ext" =~ [cC][bB][zZ] ]]; then
            unzip -q "$file" -d "$target_dir"
        elif [[ "$ext" =~ [cC][bB][rR] ]]; then
            rar x -inul "$file" "$target_dir/"
        fi
    fi

    i=$((i+1))
done

if ! $DRY_RUN; then
    # Nettoyage fichiers inutiles
    find "$TEMP_DIR" -type f \( -iname ".DS_Store" -o -iname "Thumbs.db" \) -delete

    # Création archive finale
    cd "$TEMP_DIR" || exit 1
    rar a -r -ep1 "$OUTPUT_FILE" ./* > /dev/null
    log "\n${GREEN}✅ Archive finale créée : $OUTPUT_FILE${NC}"
else
    log "\n${YELLOW}🛑 Aucune extraction ni compression effectuée (mode dry-run)${NC}"
fi

# Nettoyage
[[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
