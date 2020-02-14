#!/bin/bash

for repository in $REPOSITORIES; do
  ./push_workflow_files.sh $repository | /dev/null 2>&1
done