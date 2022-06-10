#!/bin/bash
set -ueo pipefail

ARGO_DIR="argocd"

HELM="helm"
YQ="yq"
global_ret_val=0

echo "running argocd-helm check script.."

if [ -z "${CI_PROJECT_DIR-}" ]; then
  CI_PROJECT_DIR=$(pwd)
fi

echo "CI_PROJECT_DIR: ${CI_PROJECT_DIR}"

# detect/set environment vars
env=""
while getopts e: flag
do
  case "${flag}" in
    e) env=${OPTARG};;
    *) echo "usage: $0 [-e ENVIRONMENT] " >&2
         exit 1 ;;
  esac
done

if [ "${env}" == "" ]; then
  echo "ENV: lab"
else
  echo "ENV: ${env}"
fi

echo "########################################"
echo "# check helm definitions for argo apps #"
echo "########################################"
#
if [ -n "$(ls -A $ARGO_DIR)" ]; then
  while IFS= read -r i; do

    app_name=$(echo "$i" | sed "s/^${ARGO_DIR}\/\(.*\).yaml$/\1/")
    echo "found helm chart from app: ${app_name}"
    chart_name=$($YQ eval '.spec.source.chart' "${ARGO_DIR}/${app_name}.yaml")
    repo_url=$($YQ eval '.spec.source.repoURL' "${ARGO_DIR}/${app_name}.yaml")
    target_revision=$($YQ eval '.spec.source.targetRevision' "${ARGO_DIR}/${app_name}.yaml")
    path=$($YQ eval '.spec.source.path' "${ARGO_DIR}/${app_name}.yaml")
    extra_values=$($YQ eval '.spec.source.helm.values' "${ARGO_DIR}/${app_name}.yaml")

    echo " parsed app name: \"$app_name\""
    echo " parsed chart name: \"$chart_name\" (optional)"
    echo " parsed repoURL: \"$repo_url\""
    echo " parsed targetRevision: \"$target_revision\""
    echo " parsed path: \"$path\""

    values_file="${CI_PROJECT_DIR}/extra-values-${app_name}.yaml"
    echo "$extra_values" >"$values_file"

    if [ -z "$repo_url" ] ||
      [ "$repo_url" == "null" ] ||
      [ -z "$target_revision" ] ||
      [ "$target_revision" == "null" ]; then
      echo "ERROR: parsing repoURL or targetRevision failed"
      if [ "12" -gt "$global_ret_val" ]; then
        global_ret_val="12"
      fi
    else
      # check if we are using helm repo or git repo
      if [ -z "$chart_name" ] || [ "$chart_name" == "null" ]; then
        echo "INFO: helm chart from git repo.."

        git config --global advice.detachedHead false
        git clone --branch "$target_revision" --depth=1 "$repo_url" "$app_name"
        cd "$app_name"
        # git checkout "$target_revision"

        if [ -n "$path" ] && [ "$path" != "null" ] && [ "$path" != "." ]; then
          cd "$path"
        fi
      else
        echo "INFO: helm chart form helm repo.."
        $HELM pull "$chart_name" --version "${target_revision}" --repo "${repo_url}" --untar
        cd "$chart_name"
      fi

      # check for images in chart
      # helm trivy -trivyargs '--severity HIGH,CRITICAL' .
      pwd
      if test -f "Chart.yaml"; then
        echo "running helm template"
        helm template . --values "$values_file" | yq e '..|.image? | select(.)' - | sort -u >images.list
        check_ret_val=$?
        echo "printing image list"
        cat images.list

        echo "running trivy scan"
        while IFS= read -r i; do
          if [ "$i" != "---" ]; then
            echo "scanning image: $i"
            trivy image \
              --no-progress \
              --ignore-unfixed \
              "$i"

            echo "scanning image with sarif file: $i"

            image_name=$(echo "${i}" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/_/g | sed -r s/^-+\|-+$//g)
            mkdir -p "${CI_PROJECT_DIR}/results/${app_name}"
            echo "sarif file: ${CI_PROJECT_DIR}/results/${app_name}/${image_name}.sarif"

            trivy image \
              --no-progress \
              --ignore-unfixed \
              --format sarif \
              --output "${CI_PROJECT_DIR}/results/${app_name}/${image_name}.sarif" \
              "$i"
          fi
        done < <(cat images.list)
      else
        echo "kustomize"
        echo "T.B.A."
        check_ret_val=$?
      fi

      rm images.list || true

      echo "helm return value: $check_ret_val"

      if [ "$check_ret_val" -gt "$global_ret_val" ]; then
        global_ret_val=$check_ret_val
      fi
    fi
    cd "${CI_PROJECT_DIR}"
  done < <(find "${ARGO_DIR}" -maxdepth 1 -type f)
fi

exit "$global_ret_val"
