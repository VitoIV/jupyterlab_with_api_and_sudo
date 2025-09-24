FROM jupyter/base-notebook:python-3.11

USER root

RUN pip install --no-cache-dir \
    "jupyterlab==4.*" \
    jupyter-server-proxy \
    fastapi \
    "uvicorn[standard]"

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo curl ca-certificates \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && printf "jovyan ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/010_jovyan-nopasswd \
 && chmod 0440 /etc/sudoers.d/010_jovyan-nopasswd

SHELL ["/bin/bash", "-lc"]

RUN cat > /usr/local/bin/start-all.sh <<'EOF' && chmod +x /usr/local/bin/start-all.sh
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${HOME}/.jupyter"
if [ ! -f "${HOME}/.jupyter/jupyter_server_config.py" ]; then
  cat > "${HOME}/.jupyter/jupyter_server_config.py" <<'PY'
c = get_config()
c.ServerApp.jpserver_extensions = {"jupyter_server_proxy": True}
PY
fi

mkdir -p "${HOME}/api_scripts"
if [ ! -f "${HOME}/api_scripts/hello.py" ]; then
  cat > "${HOME}/api_scripts/hello.py" <<'PY'
def main(name="world", **kwargs):
    return {"message": f"Hello, {name}!"}
PY
fi

python - <<'PY' &
import os, re, importlib, sys, traceback
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import uvicorn

SECRET = os.environ.get("API_SHARED_KEY", "velmitajneheslo")
SCRIPTS = os.path.join(os.environ["HOME"], "api_scripts")
if SCRIPTS not in sys.path:
    sys.path.insert(0, SCRIPTS)

app = FastAPI(title="Lab API", docs_url=None, redoc_url=None)

def load_module(name):
    if not name or not re.fullmatch(r"[A-Za-z0-9_]+", name or ""):
        raise ValueError("invalid_name")
    mod = importlib.import_module(name)
    try:
        importlib.reload(mod)
    except Exception:
        pass
    return mod

def call_entry(mod, params):
    if hasattr(mod, "main"): return mod.main(**params)
    if hasattr(mod, "handler"): return mod.handler(**params)
    raise AttributeError("no_entrypoint")

def run_impl(key, name, params, debug=False):
    if key != SECRET:
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    try:
        m = load_module(name)
        for k in ("key","name","debug"): params.pop(k, None)
        out = call_entry(m, params)
        if isinstance(out, (dict, list, str, int, float, bool)) or out is None:
            return JSONResponse({"ok": True, "result": out})
        return JSONResponse({"ok": True, "result": str(out)})
    except (ValueError, AttributeError) as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)
    except Exception as e:
        body = {"ok": False, "error": "script_failed", "detail": str(e)}
        if debug:
            body["trace"] = traceback.format_exc()
        return JSONResponse(body, status_code=500)

@app.get("/healthz")
async def healthz(key: str | None = None):
    return {"ok": key == SECRET, "seen_key": bool(key)}

@app.get("/run")
async def run_get(request: Request, key: str | None = None, name: str | None = None):
    params = dict(request.query_params)
    debug = str(params.get("debug","")).lower() in ("1","true","yes")
    return run_impl(key, name, params, debug=debug)

@app.post("/run")
async def run_post(request: Request, key: str | None = None, name: str | None = None):
    q = dict(request.query_params)
    try:
        j = await request.json()
        if not isinstance(j, dict):
            j = {}
    except Exception:
        j = {}
    params = {**q, **j}
    debug = str(params.get("debug","")).lower() in ("1","true","yes")
    return run_impl(key, name, params, debug=debug)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9999, log_level="warning")
PY

exec start-notebook.py \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_remote_access=True
EOF

CMD ["/usr/local/bin/start-all.sh"]
