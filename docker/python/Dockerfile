# ampseeker/python — replaces envs/AmpSeeker-python.yaml
# papermill, jupyter, pandas, scikit-allel, plotly
#
# withName routing (conf/base.config):
#   PAPERMILL_.*|BCL_MERGE_FASTQS|CREATE_PLOIDY_FILE|METADATA_COLOURS|BUILD_METADATA
FROM condaforge/miniforge3:24.9.2-0

COPY environment.yml /tmp/environment.yml
RUN mamba env create -n ampseeker -f /tmp/environment.yml \
    && mamba clean --all --yes \
    && rm /tmp/environment.yml \
    # register the Jupyter kernel the notebooks name; --prefix (not --user) works for any host user ID
    && /opt/conda/envs/ampseeker/bin/python -m ipykernel install \
        --name=AmpSeq_python --prefix=/opt/conda/envs/ampseeker \
    && chmod -R a+rX /opt/conda/envs/ampseeker

ENV PATH=/opt/conda/envs/ampseeker/bin:$PATH \
    HOME=/tmp \
    # preload libgomp: scikit-learn loads it late and otherwise fails with "cannot allocate memory in static TLS block"
    LD_PRELOAD=/opt/conda/envs/ampseeker/lib/libgomp.so.1

ENTRYPOINT []
CMD ["/bin/bash"]
