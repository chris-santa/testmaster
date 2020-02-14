#!/bin/bash

for repository in $REPOSITORIES; do
  DEVNULL=$(./push_workflow_files.sh $repository)
done