#!/bin/bash
set -ueo pipefail

#HELM="helm"
#YQ="yq"
#global_ret_val=0
GITHUB_BASE_REF_DEFAULT="main"

SCENARIOS=""

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

if [ "${GITHUB_REF_NAME}" == "" ]; then
  echo "ERROR: empty GITHUB_REF_NAME var!"
  exit 12
fi

if [ "${GITHUB_BASE_REF}" == "" ]; then
  echo "WARNING: empty GITHUB_BASE_REF var! defaulting to ${GITHUB_BASE_REF_DEFAULT}"
  GITHUB_BASE_REF="$GITHUB_BASE_REF_DEFAULT"
fi

detect_updated_files() {
  echo "current git ref: $GITHUB_REF_NAME"
  echo "fetching base ref from origin:"
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

      echo "INFO: adding into test queue"
      if [[ ${file} =~ ^argocd/prometheus-stack\.yaml$ ]]; then
        echo "INFO: add scenario prometheus-stack to queue"
        SCENARIOS+=" ./monitoringStack/... "
        #      elif [[ "${file}" =~ ^argocd/logging-stack.yaml$ ]]; then
        #        echo "INFO: add scenario deploy-argocd to queue"
        #        scenario_queue+=('deploy-argocd')
      elif [[ ${file} =~ ^argocd/.*$ ]]; then
        echo "ERROR: this test scenario doesn't exist"
        # TODO: add scenarios for rest of the roles
      else
        echo "INFO: skip non-app file"
      fi
    else
      echo "ERROR: file (${file}) not exists.. skipping apply"
    fi
  done < <(echo "$diff_output")

  export SCENARIOS

  echo "SCENARIOS=$SCENARIOS" >>"$GITHUB_ENV"

  echo -e "\ngit diff retval: ${diff_retval}"
}

detect_updated_files
