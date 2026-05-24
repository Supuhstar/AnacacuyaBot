#!/bin/bash



###
### Run this script to run the bot. It tries to take care of everything.
###
### - Parameters:
###   - --allow-stale-branch:      _optional_ - Set this flag to guarantee that the current Git commit is the one to run.
###                                Omit this flag to check for fresher Git commits on the default branch.
###                                If you're on a non-default branch, this flag does nothing and the current commit is used.
###
###   - --fail-if-model-not-found: _optional_ - Set this flag to exit with a nonzero code if the Ollama model needed to run this bot isn't yet downloaded.
###                                Omit this flag to attempt to download that model if it's missing.
###                                If you've already got the model available and ready, this flag does nothing and that model is used.
###
###   - --reset:                   _optional_ - Reset all stored state, such as token stores, then exit.
###                                Other parameters are ignord.
###



# MARK: - Parse arguments

ALLOW_STALE_BRANCHES=false
FAIL_IF_MODEL_NOT_FOUND=false
RESET_STORED_STATE=false
for arg in "$@"; do
    case "$arg" in
        --allow-stale-branch)
            ALLOW_STALE_BRANCHES=true
            ;;
        
        --fail-if-model-not-found)
            FAIL_IF_MODEL_NOT_FOUND=true
            ;;
        
        --reset)
            RESET_STORED_STATE=true
            ;;
    esac
done



# MARK: - Check if we're on a stale branch

if ! $ALLOW_STALE_BRANCHES; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    if [[ "$BRANCH" == "production" ]]; then
        echo "🔍 On 'production' branch. Checking for updates..."
        git fetch origin production --quiet
        
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/production)
        
        if [[ "$LOCAL" != "$REMOTE" ]]; then
            echo "🏚️ 'production' branch is out of date. Pulling and starting again..."
            git pull origin production --quiet
            exec "$0" "$@" || exit $?
            exit 0
        else
            echo "✅ On the latest 'production' commit."
        fi
    fi
fi



# MARK: - Try to load bot token from keyring



# MARK: getToken

getToken_security() {
    security find-generic-password \
        -a "$USER" \
        -s "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        -w
}


getToken_secret_tool() {
    secret-tool lookup \
        service "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        user "$USER"
}


getToken_pass() {
    pass show "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}"
}


getToken() {
    if command -v pass &>/dev/null; then
        getToken_pass
    elif command -v security &>/dev/null; then
        getToken_security
    elif command -v secret-tool &>/dev/null; then
        getToken_secret_tool
    else
	    echo "❌ You need to set TELEGRAM_BOT_TOKEN or install a keyring on this machine which can contain the token (currently supported: 'pass', 'security', and 'secret-tool')." >&2
        return 11
    fi
}


# MARK: storeToken

storeToken_security() {
    local token="$1"
    security add-generic-password \
        -a "$USER" \
        -s "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        -w "$token" \
        -U
}


storeToken_secret_tool() {
    local token="$1"
    echo -n "$token" | secret-tool store \
        --label="TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        service "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        user "$USER"
}


storeToken_pass() {
    local token="$1"
    echo -n "$token" | pass insert --echo "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}"
}


storeToken() {
    local token="$1"
    if command -v pass &>/dev/null; then
        storeToken_pass "$token"
    elif command -v security &>/dev/null; then
        storeToken_security "$token"
    elif command -v secret-tool &>/dev/null; then
        storeToken_secret_tool "$token"
    else
	    echo "❌ You need to set TELEGRAM_BOT_TOKEN or install a keyring on this machine which can contain the token (currently supported: 'pass', 'security', and 'secret-tool')." >&2
        return 11
    fi
}


# MARK: clearToken

deleteToken_security() {
    security delete-generic-password \
        -a "$USER" \
        -s "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}"
}


deleteToken_secret_tool() {
    secret-tool clear \
        service "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}" \
        user "$USER"
}


deleteToken_pass() {
    pass rm "TELEGRAM_BOT_TOKEN-${TELEGRAM_BOT}"
}


deleteToken() {
    didDelete=false
    if command -v pass &>/dev/null; then
        deleteToken_pass
        didDelete=$?
    fi
    if command -v security &>/dev/null; then
        deleteToken_security
        didDelete=$?
    fi
    if command -v secret-tool &>/dev/null; then
        deleteToken_secret_tool
        didDelete=$?
    fi
    
    if [[ ! didDelete ]]; then
        echo "❌ No keyring backend found (currently supported: 'pass', 'security', 'secret-tool')." >&2
        return 11
    fi
}


# MARK: If we're just resetting, reset

if $RESET_STORED_STATE; then
    deleteToken
    exit $?
fi



# MARK: Make sure token is in-place

if [[ -z "${TELEGRAM_BOT_TOKEN}" ]]; then
    echo "TELEGRAM_BOT_TOKEN is not set. Attempting to read from keyring..." >&2
    if [[ -z "${TELEGRAM_BOT}" ]]; then
        echo "❌ Neither TELEGRAM_BOT_TOKEN nor TELEGRAM_BOT is set. \
                Set TELEGRAM_BOT to the @username of the bot you want to run. For example, if your bot is '@AwesomeBot', set 'export TELEGRAM_BOT=AwesomeBot'.\
                Alternatively, if you're comfortable with lower security, set TELEGRAM_BOT_TOKEN to the token which the @BotFather gave you on Telegram. For example, 'export TELEGRAM_BOT_TOKEN=jskifhefkizuehnfizhediwurfhewku'.
                " >&2
        exit 12
    fi
    
    export TELEGRAM_BOT_TOKEN=$(getToken)
    getToken_status=$?
    
    if [[ $getToken_status -eq 11 ]]; then
        # No keyring backend at all — hard fail
        exit $getToken_status
    elif [[ -z "${TELEGRAM_BOT_TOKEN}" ]]; then
        # Keyring exists but no entry yet — offer to save
        echo "No token found in keyring for @${TELEGRAM_BOT}."
        read -rsp "Paste your bot token here to store it securely: " new_token
        echo
        storeToken "$new_token" || exit $?
        TELEGRAM_BOT_TOKEN="$new_token"
        echo "✅ ${TELEGRAM_BOT} Token saved to keyring. It will automatically be read from that keyring in future runs as long as you set 'export TELEGRAM_BOT=\"${TELEGRAM_BOT}\"'."
    fi
fi




# MARK: - Basic requirements check

if [[ -z "${TELEGRAM_BOT_TOKEN}" ]]; then
    echo "❌ You need to set TELEGRAM_BOT_TOKEN to the token @BotFather assigned to your bot" >&2
    exit 10
fi


OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-"http://localhost:11434"}

if ! curl -sf "${OLLAMA_BASE_URL}" &>/dev/null; then
    echo "❌ Ollama is not reachable at ${OLLAMA_BASE_URL}. Make sure Ollama is running." >&2
    exit 20
fi



# MARK: - Run

swift run --run $@
