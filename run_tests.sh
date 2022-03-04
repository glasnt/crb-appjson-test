#!/bin/bash

if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
  echo "GOOGLE_CLOUD_PROJECT must be set"
  exit 1
fi

if [ -z "$GOOGLE_CLOUD_REGION" ]; then
  echo "GOOGLE_CLOUD_REGION must be set"
  exit 1
fi

if [ -z "$BUTTON_IMAGE" ]; then
  BUTTON_IMAGE="cloud-run-button"
fi


if [ -z "$WORKING_DIR" ]; then
  WORKING_DIR="/workspace/cloud-run-button"
fi


readonly GIT_URL="https://github.com/glasnt/crb-appjson-test"
readonly GIT_BRANCH="integration_tests"
readonly GIT_DIR=$(echo $GIT_URL | rev | cut -d'/' -f 1 | rev)

function run_test() {
  local DIR=$1
  local EXPECTED=$2
  local CLEAN=$3

  if [ "$CLEAN" != "false" ]; then
    gcloud run services delete $DIR --platform=managed --project=$GOOGLE_CLOUD_PROJECT --region=$GOOGLE_CLOUD_REGION --quiet
  fi

  echo "Running Cloud Run Button on $GIT_URL branch $GIT_BRANCH dir tests/$DIR"

  echo ${WORKING_DIR}/cloudshell_open --repo_url=$GIT_URL --git_branch=$GIT_BRANCH --dir=integration_tests/$DIR

  ${WORKING_DIR}/cloudshell_open --repo_url="$GIT_URL" --git_branch="$GIT_BRANCH" --dir=tests/$DIR

  SERVICE_URL=$(gcloud run services describe $DIR --project=$GOOGLE_CLOUD_PROJECT --region=$GOOGLE_CLOUD_REGION --platform=managed --format 'value(status.url)')

  echo "Cleaning up content in $GIT_DIR"
  rm $GIT_DIR -rf
}

function expect_body() {
  local DIR=$1
  local EXPECTED=$2
  local CLEAN=$3

  run_test "$DIR" "$EXPECTED" "$CLEAN"

  OUTPUT=$(curl -s $SERVICE_URL)

  if [ -n "$EXPECTED" ]; then
    printf "Output:\n$OUTPUT\n\n"
    printf "Expected:\n$EXPECTED\n\n"

    if [ "${OUTPUT#*$EXPECTED}" != "$OUTPUT" ] && [ ${#OUTPUT} -eq ${#EXPECTED} ]; then
      printf "Test passed!\n\n"
    else
      printf "Test failed!\n"
      exit 1
    fi
  fi
}

function expect_status() {
  local DIR=$1
  local EXPECTED=$2
  local CLEAN=$3

  run_test "$DIR" "$EXPECTED" "$CLEAN"

  local STATUS=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL)

  printf "Status: $STATUS\n"
  printf "Expected: $EXPECTED\n"

  if [ "$STATUS" -eq "$EXPECTED" ]; then
    printf "Test passed!\n\n"
  else
    printf "Test failed!\n"
    exit 1
  fi
}

expect_body "empty-appjson" "hello, world"

expect_body "hooks-prepostcreate-inline" "AB"

# precreate deploys (gen 1), sets GEN (gen 2), CRB deploys (gen 3), postcreate sets GEN (gen 4) but the env var GEN lags by 1 because deploying the GEN change creates a new gen
expect_body "hooks-prepostcreate-external" "3"
# the GEN should not change indicating that the precreate and postcreate did not run again since the service already exists
expect_body "hooks-prepostcreate-external" "3" "false"

# deploy an app that generates a secret and outputs it
expect_body "envvars-generated"
# check that on a subsequent deploy, the secret didn't change
expect_body "envvars-generated" "$OUTPUT" "false"

# todo: not sure how to do env vars that read stdin

expect_status "require-auth" "403"
