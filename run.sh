#!/bin/bash

set -e

# choose podman if available, otherwise docker; fail if neither
PODMAN_BIN=$(command -v podman || true)
DOCKER_BIN=$(command -v docker || true)

if [[ -n "$PODMAN_BIN" ]]; then
  if [[ -n "$DOCKER_BIN" ]]; then
    echo "Both podman and docker present — preferring podman"
  else
    echo "Using podman"
  fi
  docker() { "$PODMAN_BIN" "$@"; }
elif [[ -n "$DOCKER_BIN" ]]; then
  echo "Using docker"
else
  echo "Error: neither podman nor docker found in PATH" >&2
  exit 1
fi

rebuild=false
while getopts "r" opt; do
  case $opt in
    r)
      rebuild=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [[ "$(docker images -q anvil-experiments 2> /dev/null)" == "" ]] || [[ "$rebuild" = true ]]; then
  echo "Building Docker image : anvil-experiments"
  docker build -t anvil-experiments .
else
  echo "Docker image anvil-experiments already exists... skipping build"
fi

mkdir -p out
docker run -it -v $(pwd)/out:/workspace/Anvil-Experiments/out anvil-experiments
