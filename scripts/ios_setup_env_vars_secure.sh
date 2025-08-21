set -e

if [[ -z "$IOS_SECRETS" ]]; then
    echo "❌ Error: IOS_SECRETS environment variable is not set"
    exit 1
fi


TEMP_FILE=$(mktemp)
chmod 600 "$TEMP_FILE"

echo "$IOS_SECRETS" | jq -r 'del(.MATCH_GIT_SSH_KEY) | to_entries[] | "\(.key)=\(.value)"' >"$TEMP_FILE"

while IFS='=' read -r key value; do
    if [[ -n "$key" && -n "$value" ]]; then
        if [[ -n "$GITHUB_ENV" ]]; then

            echo "::add-mask::$value"
            echo "$key=$value" >>"$GITHUB_ENV"
        else

            export "$key"="$value"
            echo "Exported: $key=[MASKED]"
        fi
    fi
done <"$TEMP_FILE"

rm -f "$TEMP_FILE"

echo "✅ Environment variables set up securely from JSON secrets"

