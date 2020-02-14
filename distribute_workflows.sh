#!/bin/bash

for repository in $REPOSITORIES; do
  ./push_workflow_files.sh $repository
done