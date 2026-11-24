# ampseeker/jupyterbook — replaces envs/AmpSeeker-jupyterbook.yaml
# jupyter-book (final report build)
#
# withName routing (conf/base.config):
#   JUPYTER_BOOK
FROM condaforge/miniforge3:24.9.2-0

COPY environment.yml /tmp/environment.yml
RUN mamba env create -n ampseeker -f /tmp/environment.yml \
    && mamba clean --all --yes \
    && rm /tmp/environment.yml \
    && chmod -R a+rX /opt/conda/envs/ampseeker

ENV PATH=/opt/conda/envs/ampseeker/bin:$PATH \
    HOME=/tmp

ENTRYPOINT []
CMD ["/bin/bash"]
