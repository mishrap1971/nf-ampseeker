# ampseeker/bcl2fastq — replaces envs/AmpSeeker-bcl2fastq.yaml
# bcl2fastq (Illumina demultiplexer, repackaged on the community `dranew`
# channel — no official bioconda recipe exists because of Illumina's EULA).
#
# withName routing (conf/base.config):
#   BCL_CONVERT_RUN
#
# dranew::bcl2fastq only ships linux-64 builds — on Apple Silicon build with
# `PLATFORM=linux/amd64 docker/build.sh bcl2fastq`.
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
