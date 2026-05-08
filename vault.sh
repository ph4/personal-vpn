#!/bin/bash
set -euo pipefail

ENCRYTPED_PATTERN="^\$ANSIBLE_VAULT"
VAULT_NAME="defualt"
FILE_SUFFIX="vault.yml"
PASSWORD_CHECK_FILE=".vault_check"
VAULT_PASS_FILE=".vault_password"

is_encrypted() {
    grep -q "$ENCRYTPED_PATTERN" "$1"
}

cleanup() {
    rm -rf "$TMP_DIR"
}

read_password() {
    if [[ -f "$VAULT_PASS_FILE" ]]; then
        VAULT_PASSWORD=$(cat "$VAULT_PASS_FILE")
        return
    fi

    read -s -p "Vault password: " VAULT_PASSWORD

    TMP_DIR=$(mktemp -d)
    trap cleanup EXIT

    # Save the vault password in a file
    VAULT_PASS_FILE="$TMP_DIR/vault_pass"
    touch "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo "$VAULT_PASSWORD" > "$VAULT_PASS_FILE"
}

init() {
    read_password
    touch inventory/password_check
    ansible-vault encrypt --vault-id "$VAULT_NAME@$VAULT_PASS_FILE" "$PASSWORD_CHECK_FILE"
}

encrypt() {
    if ! is_encrypted "$1"; then
        ansible-vault encrypt --vault-id "$VAULT_NAME@$VAULT_PASS_FILE" "$1"
    fi
}

decrypt() {
    if is_encrypted "$1"; then
        ansible-vault decrypt --vault-id "$VAULT_NAME@$VAULT_PASS_FILE" "$1"
    fi
}

run() {
    read_password

    # Fail if the vault password is not the same as the one entered
    ansible-vault view --vault-id "$VAULT_NAME@$VAULT_PASS_FILE" "$PASSWORD_CHECK_FILE"

    # Files ending with .vault.yml are encrypted
    find -type f -name "$FILE_SUFFIX" -or -name "*.$FILE_SUFFIX" | while read -r file; do
        echo "$file"
        if [[ -f "$file" ]]; then
            "$1" "$file"
        fi
    done
}

if [[ $# -eq 0 || $1 == "encrypt" ]]; then
    run encrypt
elif [[ $1 == "decrypt" && -n "${2:-}" ]]; then
    decrypt "$2"
elif [[ $1 == "decrypt" ]]; then
    run decrypt
elif [[ $1 == "init" ]]; then
    init
else
    echo "Usage: $0 [init|decrypt|encrypt]"
fi

