#!/bin/bash

for repository in $REPOSITORIES; do
  if [[ $repository == $GITHUB_REPOSITORY || "navikt/$repository" == $GITHUB_REPOSITORY ]]; then
    echo "Should not distribute files to same repository. Skipping $repository"
  else
    ./push_workflow_files.sh $repository
  fi
done