#!/bin/bash

for repository in $REPOSITORIES; do
  echo $GITHUB_REPOSITORY
  echo $REPOSITORY
  if [[ $REPOSITORY == $GITHUB_REPOSITORY || "navikt/$REPOSITORY" == $GITHUB_REPOSITORY ]]; then
    echo "Should not distribute files to same repository. Skipping $REPOSITORY"
  else
    ./push_workflow_files.sh $repository
  fi
done