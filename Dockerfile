FROM jupyter/base-notebook:python-3.11

USER root

RUN pip install --no-cache-dir \
    "jupyterlab==4.*" \
    jupyter-server-proxy \
    fastapi \
    "uvicorn[standard]" \
    requests

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo curl ca-certificates acl \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && printf "jovyan ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/010_jovyan-nopasswd \
 && chmod 0440 /etc/sudoers.d/010_jovyan-nopasswd

COPY 00-fix-home-perms.sh /usr/local/bin/start-notebook.d/00-fix-home-perms.sh
RUN chmod 0755 /usr/local/bin/start-notebook.d/00-fix-home-perms.sh

COPY lab_api.py /usr/local/bin/lab_api.py
COPY start-all.sh /usr/local/bin/start-all.sh
RUN chmod 0755 /usr/local/bin/start-all.sh

CMD ["/usr/local/bin/start-all.sh"]