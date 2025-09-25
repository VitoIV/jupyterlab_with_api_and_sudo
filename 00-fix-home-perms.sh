#!/usr/bin/env bash
set -e
mkdir -p /home/jovyan/api_scripts /home/jovyan/.jupyter
setfacl -Rb /home/jovyan || true
chown -R "${NB_UID}:${NB_GID}" /home/jovyan
chmod -R u+rwX,g+rwX,o-rwx /home/jovyan
find /home/jovyan -type d -exec chmod g+s {} \;