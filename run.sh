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



# MARK: - Parse arguments

ALLOW_STALE_BRANCHES=false
FAIL_IF_MODEL_NOT_FOUND=false
for arg in "$@"; do
    case "$arg" in
        --allow-stale-branch)
            ALLOW_STALE_BRANCHES=true
            ;;
        
        --fail-if-model-not-found)
            FAIL_IF_MODEL_NOT_FOUND=true
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



# MARK: - Basic requirements check

if [[ -z "${TELEGRAM_BOT_TOKEN}" ]]; then
    echo "You need to set TELEGRAM_BOT_TOKEN to the token @BotFather assigned to your bot"
    exit 10
fi

if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama is not installed. Ollama is required for this bot."
    exit 20
fi



# MARK: - Auto-fetch model

OLLAMA_MODEL=${OLLAMA_MODEL:-"smollm2"}


model_exists() {
    local model="$1"
    ollama list | awk 'NR>1 {print $1}' | grep -qx "$model"
}


if model_exists "$OLLAMA_MODEL"; then
    echo "✅ Model '$OLLAMA_MODEL' is ready."
else
    if $FAIL_IF_MODEL_NOT_FOUND; then
        echo "❌ Model '$OLLAMA_MODEL' not found."
        exit 21
    else
        echo "Model '$OLLAMA_MODEL' not found. Downloading it..."
        
        if ! ollama pull "${OLLAMA_MODEL}"; then
            echo "❌ Failed to pull '$OLLAMA_MODEL'"
            exit 22
        fi
    fi
fi



# MARK: - Run

swift run
