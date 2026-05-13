#!/usr/bin/env bash
# DANGER: destroys the entire env. Use only in dev.
set -euo pipefail

ENV="${1:?env required (dev | prod)}"
if [ "$ENV" = "prod" ]; then
  echo "Refusing to teardown prod. Edit this script if you really mean it."
  exit 1
fi

pushd "terraform/envs/${ENV}" > /dev/null
terraform destroy
popd > /dev/null
