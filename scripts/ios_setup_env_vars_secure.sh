set -e
# Track command execution status
STATUS=0

if [[ -z "$IOS_SECRETS" ]]; then
    echo "❌ Error: IOS_SECRETS environment variable is not set"
    exit 1
fi

TEMP_FILE=$(mktemp) || STATUS=$?
chmod 600 "$TEMP_FILE" || STATUS=$?

echo "$IOS_SECRETS" | jq -r 'del(.MATCH_GIT_SSH_KEY) | to_entries[] | "\(.key)=\(.value)"' >"$TEMP_FILE" || STATUS=$?

while IFS='=' read -r key value; do
    if [[ -n "$key" && -n "$value" ]]; then
        if [[ -n "$GITHUB_ENV" ]]; then

            echo "$value" | tr -d '\n' | xargs -0 -I {} echo "::add-mask::{}" || STATUS=$?
            echo "$key=$value" >>"$GITHUB_ENV" || STATUS=$?
        else

            export "$key"="$value" || STATUS=$?
            echo "Exported: $key=[MASKED]" || STATUS=$?
        fi
    fi
done <"$TEMP_FILE"

rm -f "$TEMP_FILE" || STATUS=$?

# Only display success message if all commands were successful
if [ $STATUS -eq 0 ]; then
    echo "✅ Environment variables set up securely from JSON secrets"
else
    echo "❌ Error: Failed to set up environment variables securely"
    exit $STATUS
fi
