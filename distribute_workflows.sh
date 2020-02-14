#!/bin/bash

for repository in $REPOSITORIES; do
  echo $repository
  ./push_workflow_files.sh $repository
done