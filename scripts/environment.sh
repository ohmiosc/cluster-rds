#!/usr/bin/env bash

set -e

environment_dev() {
  export ENV=dev
  export REGION=eu-west-1
}

environment_pre() {
  export ENV=pre
  export REGION=us-west-2
}

environment_prod() {
  export ENV=prod
  export REGION=us-east-1
}

case "$1" in
"dev")
    environment_dev ${@:2}
    ;;
"pre")
    environment_pre ${@:2}
    ;;
"prod")
    environment_prod ${@:2}
    ;;
*)
    echo -e "\n\n\n$ER [APP] No se especifico un ambiente valido\n"
    ;;
esac
