# OpenShift deployment

This deployment keeps the Gateway on pod loopback. The only public listener is
the OpenShift OAuth proxy, which supplies `x-forwarded-user` after login.
OpenClaw's trusted-proxy mode allowlists those OpenShift usernames and uses
that identity for profiles, presence, and chat attribution.

## Before applying

1. Copy `overlays/team-example` to an untracked sibling such as
   `overlays/my-team`, then edit its `openclaw.json` and `route.yaml`.
2. Replace `TEAM_USER_1` and `TEAM_USER_2` with OpenShift usernames. These
   are usernames, not necessarily email addresses.
3. Set the same public host in `openclaw.json` (`allowedOrigins`) and in
   `route.yaml` (`spec.host`).
4. Configure a model provider in `openclaw.json`. The example uses
   `OPENAI_API_KEY`; replace the model/provider configuration if your team
   uses another provider.
5. Create the project, then seal the three runtime secrets locally. The helper
   writes them under the ignored `overlays/my-team` directory; do not commit
   either plaintext or sealed Secret manifests.

```bash
oc new-project claw-commons
cp -R deploy/openshift/overlays/team-example deploy/openshift/overlays/my-team
OUTPUT_DIR=deploy/openshift/overlays/my-team/secrets \
  bash scripts/seal-openshift-secrets.sh
```

The helper prompts for the OpenAI key without echoing it and generates the
OAuth cookie secret and internal Gateway password. It requires a working `oc`
context plus `kubeseal`; set `SEALED_SECRETS_CONTROLLER_NAME` or
`SEALED_SECRETS_CONTROLLER_NAMESPACE` if your cluster uses non-default values.
The internal password is only for same-pod Gateway clients that do not travel
through OAuth. It is not a browser credential and must never be placed in the
Route URL.

## Apply and verify

```bash
oc apply -k deploy/openshift/overlays/my-team
oc -n claw-commons rollout status deployment/claw-commons
oc -n claw-commons get route claw-commons
```

Open the Route without a `#token=` fragment. OpenShift should redirect you to
login, then the OpenClaw WebChat should connect automatically. Each teammate
can open the profile page to choose a display name and avatar. Everyone must
use the same `?session=agent:commons:main` URL to participate in the shared
chat.

## Security model

- The OAuth proxy must remain the only network path to the Gateway. The
  Gateway binds to loopback, and the Service targets only the proxy port.
- `allowUsers` is the team access boundary. Keep it explicit for this
  one-off deployment. An empty list allows every authenticated OpenShift user.
- Browser devices are automatically approved with `operator.read` and
  `operator.write`, never `operator.admin` or approval scopes.
- The shared agent should have no personal credentials and only the tools the
  team intends to use. Treat every admitted teammate as able to read its
  shared conversations and state.
- The PVC holds conversation and profile state. Back it up or delete it under
  your team's retention policy.

This uses OpenClaw's trusted-proxy authentication contract. It is only safe
because the OAuth proxy overwrites the identity headers and direct Gateway
access is confined to the pod.
