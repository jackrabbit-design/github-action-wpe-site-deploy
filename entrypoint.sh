#!/bin/bash -l

set -e

: ${INPUT_WPE_SSHG_KEY_PRIVATE?Required secret not set.}

#SSH Key Vars
SSH_PATH="$HOME/.ssh"
KNOWN_HOSTS_PATH="$SSH_PATH/known_hosts"
WPE_SSHG_KEY_PRIVATE_PATH="$SSH_PATH/wpe"


###
# If you'd like to expand the environments,
# Just copy/paste an elif line and the following export
# Then adjust variables to match the new ones you added in main.yml
#
# Example:
#
# elif [[ ${GITHUB_REP} =~ ${INPUT_NEW_BRANCH_NAME}$ ]]; then
#     export WPE_ENV_NAME=${INPUT_NEW_ENV_NAME};
###

# if [[ $GITHUB_REF =~ ${INPUT_PRD_BRANCH}$ ]]; then
#     export WPE_ENV_NAME=$INPUT_PRD_ENV;
# elif [[ $GITHUB_REF =~ ${INPUT_STG_BRANCH}$ ]]; then
#     export WPE_ENV_NAME=$INPUT_STG_ENV;
# elif [[ $GITHUB_REF =~ ${INPUT_DEV_BRANCH}$ ]]; then
#     export WPE_ENV_NAME=$INPUT_DEV_ENV;
# else
#     echo "FAILURE: Branch name required." && exit 1;
# fi

export WPE_SRC_NAME=$INPUT_STG_ENV;
export WPE_DST_NAME=$INPUT_PRD_ENV;

echo "Deploying $GITHUB_REF to $WPE_DST_NAME..."

#Deploy Vars
WPE_SRC_SSH_HOST="$WPE_SRC_NAME.ssh.wpengine.net"
WPE_DST_SSH_HOST="$WPE_DST_NAME.ssh.wpengine.net"
WPE_GIT_HOST="git.wpengine.com"
DIR_PATH="$INPUT_TPO_PATH"
SRC_PATH="$INPUT_TPO_SRC_PATH"
ACF_PATH="$INPUT_ACF_PATH"

# Set up our user and path

WPE_SRC_SSH_USER="$WPE_SRC_NAME"@"$WPE_DST_SSH_HOST"
WPE_SOURCE=wpe_gha+"$WPE_SRC_SSH_USER":sites/"$WPE_SRC_NAME"/"$ACF_PATH"

WPE_DST_SSH_USER="$WPE_DST_NAME"@"$WPE_DST_SSH_HOST"
WPE_DESTINATION=wpe_gha+"$WPE_DST_SSH_USER":sites/"$WPE_DST_NAME"/"$DIR_PATH"

WPE_GIT_DESTINATION="git@git.wpengine.com:production/$WPE_DST_NAME.git"
WPE_GIT_BRANCH_DESTINATION="refs/heads/master"

# Setup our SSH Connection & use keys
mkdir "$SSH_PATH"
ssh-keyscan -t rsa "$WPE_DST_SSH_HOST" >> "$KNOWN_HOSTS_PATH"
ssh-keyscan -t rsa "$WPE_GIT_HOST" >> "$KNOWN_HOSTS_PATH"

# Copy Secret Keys to container
echo "$INPUT_WPE_SSHG_KEY_PRIVATE" > "$WPE_SSHG_KEY_PRIVATE_PATH"

#Set Key Perms
chmod 700 "$SSH_PATH"
chmod 644 "$KNOWN_HOSTS_PATH"
chmod 600 "$WPE_SSHG_KEY_PRIVATE_PATH"

echo "Adding ssh agent ..."
eval `ssh-agent -s`
ssh-add $WPE_SSHG_KEY_PRIVATE_PATH
ssh-add -l

rsync "$WPE_SOURCE" $INPUT_FLAGS --exclude-from='/exclude.txt' $ACF_PATH --rsh="ssh -v -p 22 -i ${WPE_SSHG_KEY_PRIVATE_PATH} -o StrictHostKeyChecking=no"

# Deploy via SSH
# Exclude restricted paths from exclude.txt
rsync --rsh="ssh -v -p 22 -i ${WPE_SSHG_KEY_PRIVATE_PATH} -o StrictHostKeyChecking=no" $INPUT_FLAGS --exclude-from='/exclude.txt' $SRC_PATH "$WPE_DESTINATION"

# Post deploy clear cache
if [ "${INPUT_CACHE_CLEAR^^}" == "TRUE" ]; then
    echo "Clearing WP Engine Cache..."
    ssh -v -p 22 -i ${WPE_SSHG_KEY_PRIVATE_PATH} -o StrictHostKeyChecking=no $WPE_DST_SSH_USER "cd sites/${WPE_DST_NAME} && wp page-cache flush"
    echo "SUCCESS: Site has been deployed and cache has been flushed."
else
    echo "Skipping Cache Clear."
fi