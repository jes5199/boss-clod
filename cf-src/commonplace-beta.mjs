// beta.commonplace.st — phase 1 target. Deployed by cf-deploy.sh, which writes its own provenance.
const HTML = `<!doctype html><meta charset=utf-8><title>commonplace beta</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:34rem;margin:12vh auto;padding:0 1.5rem;
color:#1a1a1a;background:#faf9f7}code{background:#eee7e0;padding:.1em .35em;border-radius:3px}
.m{color:#6b6560;font-size:.9em}</style>
<h1>commonplace &mdash; beta</h1>
<p>This is a deployed placeholder. It exists to prove the deployment path end to end:
a Worker, reachable over TLS, carrying its own provenance record.</p>
<p class=m>Deployed by <code>cf-deploy.sh</code> under commonplace-plan row 218.
Provenance: <code>cf-records/commonplace-beta.md</code>, and on the artifact itself as
<code>prov:*</code> tags.</p>`;
export default {
  fetch(req) {
    const u = new URL(req.url);
    if (u.pathname === "/healthz")
      return Response.json({ ok: true, service: "commonplace-beta", phase: 1 });
    return new Response(HTML, { headers: { "content-type": "text/html; charset=utf-8" } });
  },
};
