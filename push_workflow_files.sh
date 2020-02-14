#!/bin/bash

IFS=

### Create new tree
function createNode {
  WORKFLOW_FILE_NAME=$(echo $1 | rev | cut -f1 -d"/" | rev)
  CONTENT=$(cat $1)
  echo $(jq -n -c \
              --arg path ".github/workflows/$WORKFLOW_FILE_NAME" \
              --arg content "$CONTENT" \
              '{ path: $path, mode: "100644", type: "blob", content: $content }'
  )
}

if [[ $1 =~ ".+/.+" ]]; then
  REPOSITORY=$1
else
  REPOSITORY="navikt/$1"
fi

echo "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master"

curl -s "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master"

BASE_TREE_SHA=$(curl -s "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master" | jq -r '.object.sha')

for file in "./$WORKFLOW_DIRECTORY"/*; do
  TREE_NODES="$TREE_NODES$(createNode $file),"
done

TREE_NODES="[$(echo $TREE_NODES | sed 's/,$//')]"

CREATE_TREE_PAYLOAD=$(jq -n -c \
                      --arg base_tree $BASE_TREE_SHA \
                      '{ base_tree: $base_tree, tree: [] }'
)

CREATE_TREE_PAYLOAD=$(echo $CREATE_TREE_PAYLOAD | jq -c '.tree = '"$TREE_NODES")

UPDATED_TREE_SHA=$(curl -s -X POST -u "$API_ACCESS_TOKEN:" --data "$CREATE_TREE_PAYLOAD" "https://api.github.com/repos/$REPOSITORY/git/trees" | jq -r '.sha')


## Create commit based on new tree
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

curl -s -X PATCH -u "$API_ACCESS_TOKEN:" --data "$PUSH_COMMIT_PAYLOAD" "https://api.github.com/repos/$REPOSITORY/git/refs/heads/master"