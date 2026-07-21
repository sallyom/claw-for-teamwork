#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-claw-commons}"
output_dir="${OUTPUT_DIR:-deploy/openshift/overlays/my-team/secrets}"
controller_name="${SEALED_SECRETS_CONTROLLER_NAME:-sealed-secrets-controller}"
controller_namespace="${SEALED_SECRETS_CONTROLLER_NAMESPACE:-kube-system}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

for command in oc kubeseal openssl; do
  command -v "$command" >/dev/null || {
    echo "missing required command: $command" >&2
    exit 1
  }
done

printf 'OpenAI API key (input hidden): ' >&2
IFS= read -r -s openai_key
printf '\n' >&2
test -n "$openai_key" || {
  echo "OpenAI API key must not be empty" >&2
  exit 1
}

printf '%s' "$openai_key" > "$tmp_dir/openai-api-key"
unset openai_key
openssl rand -hex 16 > "$tmp_dir/cookie_secret"
openssl rand -hex 32 > "$tmp_dir/password"

seal() {
  local secret_name="$1"
  local secret_file="$2"
  oc -n "$namespace" create secret generic "$secret_name" \
    --from-file="$3" \
    --dry-run=client \
    -o yaml > "$secret_file"
  kubeseal \
    --controller-name "$controller_name" \
    --controller-namespace "$controller_namespace" \
    --format yaml < "$secret_file" > "$tmp_dir/$secret_name.sealedsecret.yaml"
}

seal openclaw-provider "$tmp_dir/openclaw-provider.secret.yaml" "OPENAI_API_KEY=$tmp_dir/openai-api-key"
seal openclaw-oauth-config "$tmp_dir/openclaw-oauth-config.secret.yaml" "cookie_secret=$tmp_dir/cookie_secret"
seal openclaw-internal-auth "$tmp_dir/openclaw-internal-auth.secret.yaml" "password=$tmp_dir/password"

mkdir -p "$output_dir"
mv "$tmp_dir"/*.sealedsecret.yaml "$output_dir/"
cat > "$output_dir/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - openclaw-provider.sealedsecret.yaml
  - openclaw-oauth-config.sealedsecret.yaml
  - openclaw-internal-auth.sealedsecret.yaml
EOF
echo "Wrote sealed secrets to $output_dir"
