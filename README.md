# The Claw Commons

An OpenShift deployment for a shared OpenClaw WebChat. Each person signs in
with OpenShift OAuth; OpenClaw records the authenticated person as the sender
and lets them maintain their own display name and avatar.

This is an experimental, single-team deployment. It is deliberately separate
from the OpenClaw operator and is not a multi-tenant service.

Its main agent is `commons`. See [the OpenShift deployment guide](deploy/openshift/README.md).
