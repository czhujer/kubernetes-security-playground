#!/bin/bash
set -ueo pipefail

set -x

HELM="helm"
YQ="yq"
global_ret_val=0
git_original_branch="main"

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
  echo "show git remote"
  git remote -v
  echo "show git branch"
  git branch -v

  echo "current git branch: $GITHUB_HEAD_REF"

  echo "fetch original branch (${git_original_branch})"
  git fetch origin "${git_original_branch}:${git_original_branch}"

#  diff_output=$(git diff --name-status "origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" -- ./*)
#  diff_retval=$?
  git diff --name-status "origin/$GITHUB_HEAD_REF" -- "./${ARGO_DIR}/*"

#  role_prefix="ansible/roles"
#  tests_prefix="ansible/molecule"

#  while IFS= read -r file; do
#    echo "DEBUG: changed file: ${file}"
#    if [[ "${file}" =~ ^.*[[:space:]]"${role_prefix}/k8s-prometheus".*$ ]] \
#      || [[ "${file}" =~ ^.*[[:space:]]"${tests_prefix}/deploy-prometheus".*$ ]] \
#    ; then
#      echo "INFO: add scenario deploy-prometheus to queue"
#      scenario_queue+=('deploy-prometheus')
#    elif [[ "${file}" =~ ^.*[[:space:]]"${role_prefix}/k8s-rook-ceph".*$ ]] \
#      || [[ "${file}" =~ ^.*[[:space:]]"${tests_prefix}/deploy-rook-ceph".*$ ]] \
#    ; then
#      echo "INFO: add scenario deploy-rook-ceph to queue"
#      scenario_queue+=('deploy-rook-ceph')
#    elif [[ "${file}" =~ ^.*[[:space:]]"${role_prefix}/k8s-jaeger".*$ ]] \
#      || [[ "${file}" =~ ^.*[[:space:]]"${tests_prefix}/deploy-jaeger".*$ ]] \
#    ; then
#      echo "INFO: add scenario deploy-jaeger to queue"
#      scenario_queue+=('deploy-jaeger')
#    elif [[ "${file}" =~ ^.*[[:space:]]"${role_prefix}/k8s-argocd".*$ ]] \
#      || [[ "${file}" =~ ^.*[[:space:]]"${tests_prefix}/deploy-argocd".*$ ]] \
#    ; then
#      echo "INFO: add scenario deploy-argocd to queue"
#      scenario_queue+=('deploy-argocd')
#    elif [[ "${file}" =~ ^.*[[:space:]]"${role_prefix}/".*$ ]] \
#    || [[ "${file}" =~ ^.*[[:space:]]"${tests_prefix}/".*$ ]] \
#    ; then
#      echo "WARNING: this test scenario doesn't exist"
#      # TODO: add scenarios for rest of the roles
#    else
#      echo "INFO: skip non-role file"
#    fi;
#  done < <(echo "$diff_output")
#
#  echo -e "\ngit diff retval: ${diff_retval}"

}

detect_updated_files
