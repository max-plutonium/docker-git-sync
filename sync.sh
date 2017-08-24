#! /bin/bash

source /etc/sync_env

SYNC_DIR=${GIT_DIR:=/sync-dir}

function die {
    echo >&2 "$@"
    exit 1
}

echo "Starting sync at $(date -R)"

if [ -n "${GIT_REPO_URL}" ] && [ ! -d "$SYNC_DIR" ]; then
  echo "${SYNC_DIR} does not exist or is not a directory. Performing initial clone."
  git clone "${GIT_REPO_URL}" --branch "${GIT_REPO_BRANCH}" --single-branch "${SYNC_DIR}" || die "git clone failed"
elif [ ! -n "${GIT_WORK_TREE}" ] && [ ! -d "$SYNC_DIR/.git" ]; then
  echo "${SYNC_DIR} exists but does not contain a git repository. Initializing local git repository before pulling remote"
  cd "${SYNC_DIR}"

  if [ "${OVERWRITE_LOCAL}" = "true"  ]; then
    echo "Removing all existing files in that directory beforehand as requested using --overwrite-local."
    find -delete
  fi

  if [ -n "$(ls -A ${SYNC_DIR})" ]; then
    die "${SYNC_DIR} is not empty and --overwrite-local was not specified"
  fi

  git init || die "git init failed"
  git remote add origin "${GIT_REPO_URL}" || die "git remote add failed"
  git fetch origin "${GIT_REPO_BRANCH}" || die "git fetch failed"
  git checkout -t "origin/${GIT_REPO_BRANCH}" || die "git checkout failed"
fi

cd "${SYNC_DIR}"

if [ ! -n "${GIT_WORK_TREE}" ]; then
    git pull origin "${GIT_REPO_BRANCH}" || die "git pull failed"
else
    GIT_EXTRA_ARGS+=" --git-dir=${GIT_DIR} --work-tree=${GIT_WORK_TREE}"
fi

git ${GIT_EXTRA_ARGS} add --all . || die "git add failed"

git ${GIT_EXTRA_ARGS} diff-index --quiet HEAD

CHANGES_CODE=$?

if [ ${CHANGES_CODE} -ne 0 ]
then
    echo "Unsynced changes detected. Performing git commit and push."
    git ${GIT_EXTRA_ARGS} commit -a -m "Sync" || die "git commit failed"
else
    echo "No changes to commit."
fi

if [ ! -n "${GIT_WORK_TREE}" ]; then
    CHANGES_TO_PUSH=$(git diff --stat --cached "origin/${GIT_REPO_BRANCH}")

    if [ -n "${CHANGES_TO_PUSH}" ]; then
        git push origin "${GIT_REPO_BRANCH}" || die "git push failed"
    else
        echo "No changes to push"
    fi
fi
