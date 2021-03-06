#!/bin/bash
set -ueo pipefail

HELM="helm"
YQ="yq"
global_ret_val=0

run_trivy_scan() {
  echo "INFO: running trivy scan"
  while IFS= read -r i; do
    if [ "$i" != "---" ]; then
      echo "INFO: scanning image: $i"
      trivy image \
        --no-progress \
        --ignore-unfixed \
        "$i"

      echo "INFO: scanning image with sarif file: $i"

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
}

parse_argocd_defs() {
  ARGO_DIR_E=$(echo "$ARGO_DIR" | sed 's/\//\\\//g')
  app_name=$(echo "$i" | sed "s/^${ARGO_DIR_E}\/\(.*\).yaml$/\1/")
  echo "found helm chart from app: ${app_name}"
  chart_name=$($YQ eval '.spec.source.chart' "${ARGO_DIR}/${app_name}.yaml")
  repo_url=$($YQ eval '.spec.source.repoURL' "${ARGO_DIR}/${app_name}.yaml")
  target_revision=$($YQ eval '.spec.source.targetRevision' "${ARGO_DIR}/${app_name}.yaml")
  path=$($YQ eval '.spec.source.path' "${ARGO_DIR}/${app_name}.yaml")
  extra_values=$($YQ eval '.spec.source.helm.values' "${ARGO_DIR}/${app_name}.yaml")
  dir_include=$($YQ eval '.spec.source.directory.include' "${ARGO_DIR}/${app_name}.yaml")

  echo " parsed app name: \"$app_name\""
  echo " parsed chart name: \"$chart_name\" (optional)"
  echo " parsed repoURL: \"$repo_url\""
  echo " parsed targetRevision: \"$target_revision\""
  echo " parsed path: \"$path\""
  echo " parsed directory include: \"$dir_include\""

  values_file="${CI_PROJECT_DIR}/extra-values-${app_name}.yaml"
  echo "$extra_values" >"$values_file"
  echo "DEBUG: printing helm extra values:"
  cat "$values_file"
}

parse_images() {
  if test -f "Chart.yaml"; then
    echo "INFO: running helm template"
    helm template . --values "$values_file" | yq e '..|.image? | select(.)' - | sort -u >images.list
    check_ret_val=$?

  elif test -f "kustomization.yaml"; then
    echo "INFO: running kustomize build"
    kustomize build . | yq e '..|.image? | select(.)' - | sort -u >images.list
    check_ret_val=$?
  else
    echo "INFO: checking raw manifests"
    if [ "$dir_include" == "null" ]; then
      find_name="*.yaml"
    else
      echo "INFO: setup directory include to: \"$dir_include\""
      find_name="${dir_include}"
    fi

    # yq eval '..|.image? | select (.) | del(.type, .description)' ./* >images_tmp.list
    find . -name "${find_name}" -type f -exec cat {} \; | yq eval '..|.image? | select (.) | del(.type, .description)' - >images_tmp.list
    # fix for CRDs
    set +o pipefail
    grep <images_tmp.list -v "\-\-\-" | grep -v "image: null" | sort -u >images.list
    set -o pipefail
  fi

  echo "INFO: printing image list"
  cat images.list

  run_trivy_scan

  rm images.list || true
  rm images_tmp.list || true

  return $check_ret_val
}

echo "running argocd images check script.."

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

if [ -n "$(ls -A "${ARGO_DIR}")" ]; then
  while IFS= read -r i; do

    parse_argocd_defs

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
        echo "INFO: fetching data from git repo.."

        git config --global advice.detachedHead false
        git clone --branch "$target_revision" --depth=1 "$repo_url" "$app_name"
        cd "$app_name"
        # git checkout "$target_revision"

        if [ -n "$path" ] && [ "$path" != "null" ] && [ "$path" != "." ]; then
          cd "$path"
        fi
      else
        echo "INFO: fetching data form helm repo.."
        $HELM pull "$chart_name" --version "${target_revision}" --repo "${repo_url}" --untar
        cd "$chart_name"
      fi

      pwd=$(pwd)
      echo "INFO: scan folder: ${pwd}"

      parse_images
      check_ret_val=$?

      echo "INFO: parse_images return value: $check_ret_val"

      if [ "$check_ret_val" -gt "$global_ret_val" ]; then
        global_ret_val=$check_ret_val
      fi
    fi
    cd "${CI_PROJECT_DIR}"
  done < <(find "${ARGO_DIR}" -maxdepth 1 -type f)
fi

exit "$global_ret_val"
