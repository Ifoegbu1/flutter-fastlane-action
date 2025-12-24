set -e
# Track command execution status
STATUS=0

if [[ -z "$IOS_SECRETS" ]]; then
    echo -e "\033[1;31m❌ Error: IOS_SECRETS environment variable is not set\033[0m"
    exit 1
fi

TEMP_FILE=$(mktemp) || STATUS=$?
chmod 600 "$TEMP_FILE" || STATUS=$?

echo "$IOS_SECRETS" | jq -r 'to_entries[] | "\(.key)=\(.value)"' >"$TEMP_FILE" || STATUS=$?

while IFS='=' read -r key value; do
    if [[ -n "$key" && -n "$value" ]]; then
        if [[ -n "$GITHUB_ENV" ]]; then
            echo "::add-mask::$value"
            # Use multiline syntax if value contains a newline to avoid corrupting GITHUB_ENV
            if printf '%s' "$value" | grep -q $'\n'; then
                delimiter="EOF_$(date +%s%N)_$RANDOM"
                {
                    printf '%s<<%s\n' "$key" "$delimiter"
                    printf '%s\n' "$value"
                    printf '%s\n' "$delimiter"
                } >>"$GITHUB_ENV"
            else
                echo "$key=$value" >>"$GITHUB_ENV"
            fi
        else

            export "$key"="$value"
            echo -e "\033[1;34mExported: $key=[MASKED]\033[0m"
        fi
    fi
done <"$TEMP_FILE"

rm -f "$TEMP_FILE" || STATUS=$?

# Only display success message if all commands were successful
if [ $STATUS -eq 0 ]; then
    echo -e "\033[1;32m✅ Environment variables set up securely from JSON secrets\033[0m"
else
    echo -e "\033[1;31m❌ Error: Failed to set up environment variables securely\033[0m"
    exit $STATUS
fi
