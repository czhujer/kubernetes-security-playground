#!/bin/bash
set -ueo pipefail

#HELM="helm"
#YQ="yq"
#global_ret_val=0

echo "running script detect_updated_argocd_apps.sh"

if [ -z "${CI_PROJECT_DIR-}" ]; then
  CI_PROJECT_DIR=$(pwd)
fi
echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}"

# detect/set environment vars
folder=""
while getopts f: flag; do
  case "${flag}" in
  f) folder=${OPTARG} ;;
  *)
    echo "usage: $0 [-f folder] " >&2
    exit 1
    ;;
  esac
done

if [ "${folder}" == "" ]; then
  echo "SCAN_FOLDER: argocd"
  ARGO_DIR="argocd"
else
  echo "SCAN_FOLDER: ${folder}"
  ARGO_DIR=${folder}
fi

detect_updated_files() {
  echo "current git branch: $GITHUB_HEAD_REF"
  git fetch origin "${GITHUB_BASE_REF}:${GITHUB_BASE_REF}"

  #  echo "show git remote"
  #  git remote -v
  #  echo "show git branch"
  #  git branch -v

  #  diff_output=$(git diff --name-status "origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" -- ./*)
  diff_output=$(git diff --name-status "origin/$GITHUB_BASE_REF" -- "./${ARGO_DIR}/*")
  diff_retval=$?

  while IFS= read -r file; do
    file=$(echo "$file" | awk -F ' ' '{print $2}')
    echo "DEBUG: changed file: ${file}"

    # test if file exists
    if test -f "${file}"; then
      echo "INFO: apply-ing manifest ${file}"
      kubectl apply -f "${file}"
    else
      echo "ERROR: file (${file}) not exists.. skipping apply"
    fi
  done < <(echo "$diff_output")

  echo -e "\ngit diff retval: ${diff_retval}"
}

detect_updated_files
