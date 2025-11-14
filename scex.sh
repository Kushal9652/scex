#!/bin/bash

# -----------------------------------------------
#  Scope Extractor + Wildcard Subdomain Enumerator
#  Owner: kushal07
# -----------------------------------------------

# ==== COLORS ====
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

THREADS=120   # FAST + STABLE for Mac mini

# ==== HELP MENU ====
show_help() {
    echo -e "${BLUE}Scope Extractor (by kushal07)${RESET}"
    echo
    echo "Usage: $0 -i <input_json> -o <output_file>"
    echo
    echo "Options:"
    echo "  -i <file>   Input HackerOne scope JSON file"
    echo "  -o <file>   Output file name"
    echo "  -h          Show help"
    echo
    echo "Example:"
    echo "  $0 -i booking.json -o scope.txt"
    exit 0
}

# ==== ARG PARSER ====
while getopts "i:o:h" opt; do
    case $opt in
        i) INPUT="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# ==== VALIDATION ====
if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
    echo -e "${RED}[!] Missing -i or -o${RESET}"
    echo "Use -h for help."
    exit 1
fi

echo -e "${GREEN}[+] Extracting in-scope & bounty-eligible domains...${RESET}"

# ==== EXTRACT RAW DOMAINS ====
jq -r '
  .target.scope.include[]
  | select(.enabled == true)
  | .host
' "$INPUT" \
| sed 's/^\^//; s/\$//; s/\\//g' \
| sort -u > "$OUTPUT"

echo -e "${GREEN}[+] Saved cleaned domains to $OUTPUT${RESET}"
echo

# ==== DETECT WILDCARDS (*.domain.com OR .*.domain.com) ====
WILDCARDS=$(grep -E '^\*\.|^\.\*\.' "$OUTPUT")

if [[ -z "$WILDCARDS" ]]; then
    echo -e "${YELLOW}[!] No wildcard domains found. Skipping enumeration.${RESET}"
    echo -e "${GREEN}[+] Done!${RESET}"
    exit 0
fi

# ==== PRINT WILDCARDS ====
echo -e "${BLUE}[!] Wildcard domains detected:${RESET}"
echo "$WILDCARDS"
echo

# ==== ASK USER ====
read -p "[?] Enumerate wildcard domains using Subfinder? (y/n): " ENUM_CHOICE

if [[ "$ENUM_CHOICE" != "y" && "$ENUM_CHOICE" != "Y" ]]; then
    echo -e "${YELLOW}[+] Skipped enumeration.${RESET}"
    exit 0
fi

echo -e "${BLUE}[+] Starting Subfinder enumeration (threads: $THREADS)...${RESET}"
echo -e "${YELLOW}[!] Ensure Subfinder API keys are configured in ~/.config/subfinder/config.yaml${RESET}"
echo

# ==== ENUMERATE WILDCARD DOMAINS ONLY ====
echo "$WILDCARDS" | while read -r wd; do

    clean_domain=$(echo "$wd" \
        | sed 's/^\*\.\(.*\)$/\1/; s/^\.\*\.\(.*\)$/\1/')

    echo -e "${GREEN}[+] Enumerating: $clean_domain${RESET}"

    subfinder -d "$clean_domain" -all -silent -t "$THREADS" >> "$OUTPUT"

    sort -u "$OUTPUT" -o "$OUTPUT"
done

echo -e "${GREEN}[+] Wildcard subdomains appended to $OUTPUT${RESET}"
echo -e "${GREEN}[+] Done!${RESET}"