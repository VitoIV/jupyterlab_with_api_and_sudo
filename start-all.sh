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

# spustit FastAPI na pozadí
python /usr/local/bin/lab_api.py &

# spustit Jupyter
exec start-notebook.py \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_remote_access=True