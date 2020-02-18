#!/bin/bash

IFS=

### Create new tree
function createNode {
  WORKFLOW_FILE_NAME=$(basename -- $1 | sed 's/__DISTRIBUTED_//g')
  CONTENT=$(cat $1)
  echo $(jq -n -c \
              --arg path ".github/workflows/$WORKFLOW_FILE_NAME" \
              --arg content "$CONTENT" \
              '{ path: $path, mode: "100644", type: "blob", content: $content }'
  )
}

## Get latest commit sha on master
export BASE_TREE_SHA=$(curl -s -u "$API_ACCESS_TOKEN:" "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master" | jq -r '.object.sha')


## Find existing workflows in target repository
EXISTING_WORKFLOWS=$(./find_existing_workflows.sh)


## Iterate through workflow folder and only include those that differ from target workflows
for file in ./.github/workflows/__DISTRIBUTED_*; do

  echo $file

  TARGET_FILE_NAME=$(basename -- $file | sed 's/__DISTRIBUTED_//g')

  echo $TARGET_FILE_NAME

  EXISTING_FILE_SHA=$(echo $EXISTING_WORKFLOWS | jq -r '.[] | select(.path == "'"$TARGET_FILE_NAME"'").sha')
  NEW_FILE_SHA=$(git hash-object $file)

  if [[ $EXISTING_FILE_SHA != $NEW_FILE_SHA ]]; then
    TREE_NODES="$TREE_NODES$(createNode $file),"
  fi
done


## Exit if no changes are to be made
if [[ -z $TREE_NODES ]]; then
  echo "Project $REPOSITORY is already up-to-date"
  exit 0
fi

## Remove trailing comma and wrap in square brackets
TREE_NODES="[$(echo $TREE_NODES | sed 's/,$//')]"


## Create new tree on remote and keep its ref
CREATE_TREE_PAYLOAD=$(jq -n -c \
                      --arg base_tree $BASE_TREE_SHA \
                      '{ base_tree: $base_tree, tree: [] }'
)

CREATE_TREE_PAYLOAD=$(echo $CREATE_TREE_PAYLOAD | jq -c '.tree = '"$TREE_NODES")

UPDATED_TREE_SHA=$(curl -s -X POST -u "$API_ACCESS_TOKEN:" --data "$CREATE_TREE_PAYLOAD" "https://api.github.com/repos/$REPOSITORY/git/trees" | jq -r '.sha')


## Create commit based on new tree, keep new tree ref
CREATE_COMMIT_PAYLOAD=$(jq -n -c \
                        --arg message "Files distributed from $GITHUB_REPOSITORY, version $GITHUB_SHA" \
                        --arg tree $UPDATED_TREE_SHA \
                        --arg name "Personbruker Workflow Authority" \
                        --arg email "personbruker@nav.no" \
                        --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                        '{ tree: $tree, message: $message, author: { name: $name, email: $email, date: $date }, parents: [] }'
)

CREATE_COMMIT_PAYLOAD=$(echo $CREATE_COMMIT_PAYLOAD | jq -c '.parents = ["'"$BASE_TREE_SHA"'"]')

UPDATED_COMMIT_SHA=$(curl -s -X POST -u "$API_ACCESS_TOKEN:" --data "$CREATE_COMMIT_PAYLOAD" "https://api.github.com/repos/$REPOSITORY/git/commits" | jq -r '.sha')




## Push new commit
PUSH_COMMIT_PAYLOAD=$(jq -n -c \
                      --arg sha $UPDATED_COMMIT_SHA \
                      '{ sha: $sha, force: false }'
)



HEAD_SHA=$(curl -s -X PATCH -u "$API_ACCESS_TOKEN:" --data "$PUSH_COMMIT_PAYLOAD" "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master" | jq -r '.object.sha')


echo "$REPOSITORY is now on commit $HEAD_SHA"