# Usage

- [Running the pipeline](#running-the-pipeline)
- [Sample metadata](#sample-metadata)
- [Reference files](#reference-files)
- [Nanopore: Clair3 models](#nanopore-clair3-models)
- [Illumina: starting from BCL files](#illumina-starting-from-bcl-files)
- [Parameters](#parameters)
- [Resources and HPC](#resources-and-hpc)
- [Containers](#containers)
- [Troubleshooting](#troubleshooting)

## Running the pipeline

Run straight from GitHub:

```bash
nextflow run mishrap1971/nf-ampseeker -r main -profile docker [parameters]
```

or from a local git clone:

```bash
git clone https://github.com/mishrap1971/nf-ampseeker.git
cd nf-ampseeker
nextflow run . -profile docker [parameters]
```

Choose a container engine with `-profile docker` or `-profile singularity`.

Give parameters on the command line (`--dataset mydata`) or collect them in a YAML file and
pass it with `-params-file`. [`params.example.yaml`](../params.example.yaml) lists every
parameter:

```bash
nextflow run . -profile docker -params-file my_params.yaml
```

To continue a stopped or failed run without redoing finished steps, run the same command
again with `-resume` added. The `work/` folder holds intermediate files. Delete it once you
no longer need to resume.

To save disk space, delete all older runs except the last by
```bash
nextflow clean -but last -f
```


## Sample metadata

`--metadata` is a tab-separated file with one row per sample.

| Column | Needed | Notes |
|---|---|---|
| `sample_id` | always | Unique. Used in every output file name. |
| `fq1` | mandatory for nanopore | Path to the FASTQ (in case of Illumina, read 1). |
| `fq2` | Illumina | Path to read 2. |
| cohort columns | always | Default `location`, `taxon`, `country`. Used to group and colour samples in the analyses. Change them with `--cohort_columns`. |
| `latitude`, `longitude` | only with `--analysis_sample_map true` | |
| `plate`, `well_letter`, `well_number` | optional | When all three are present, the reads-per-well plot is added. |

Illumina only: if `fq1`/`fq2` are left out, reads are located as
`<reads_dir>/<sample_id>_1.fastq.gz` and `_2.fastq.gz`.

To use other cohort columns, list them in comma-separated argument:

```bash
--cohort_columns cohort,site
```

To supply your own plot colours, pass a JSON file with `--metadata_colours`. The pipeline generates
plot colours from the cohort columns.

## Reference files

| Parameter | What |
|---|---|
| `--reference_fasta` | Reference genome FASTA. |
| `--targets` | BED file of the target SNP positions. Contig names must match the FASTA. |
| `--reference_name` | Name of the reference, used as a label. |
| `--custom_snpeffdb true` + `--reference_gff3` | Build the snpEff database from the FASTA and a GFF3 file. |
| `--custom_snpeffdb false` + `--reference_snpeffdb` | Download a prebuilt snpEff database by name, e.g. `Anopheles_gambiae`. |

The `ag-vampir` panel (`--panel ag-vampir`) needs the contigs named `2L`, `2R`, `3L`, `3R`
and `X`, without a prefix, in the FASTA, GFF and BED. The pipeline stops early with a
message if they are not.

## Nanopore: Clair3 models

Nanopore amplicon calls use Clair3 2.0, which needs a PyTorch model: a folder holding
`pileup.pt` and `full_alignment.pt`. Older TensorFlow models (`pileup.index`,
`pileup.data-*`), including those fetched by the Snakemake AmpSeeker download script, do
not work and fail with a `FileNotFoundError` for `pileup.pt`.

Pick the model that matches your flow cell, kit and basecaller:

- recent R10.4.1 models: https://www.bio8.cs.hku.hk/clair3/clair3_models_pytorch/
- full catalogue (older chemistries, specific Dorado/Guppy versions):
  https://www.bio8.cs.hku.hk/clair3/clair3_models_rerio_pytorch/

```bash
m=r1041_e82_400bps_sup_v420
mkdir -p clair3_models/$m
for f in pileup.pt full_alignment.pt; do
  curl -L -o clair3_models/$m/$f https://www.bio8.cs.hku.hk/clair3/clair3_models_pytorch/$m/$f
done
```

Then pass `--clair3_model_path clair3_models/r1041_e82_400bps_sup_v420`.

Clair3 writes a gVCF per sample. Genotypes with read depth below `--min_genotype_depth`
(default=10) are set to missing (`./.`), so low-coverage samples are not counted as
wild type. Samples are merged with the reference, so a covered sample without the variant
is `0/0` and a sample with no data is `./.`. This is crucial for allele-frequency estimates.

If Clair3 fails for a sample, it is retried twice, then skipped so the rest of the run
can finish. Check the run's log file to identify skipped samples.

`--ploidy 1` adds Clair3's haploid options. Nanopore runs accept ploidy 1 or 2 only.

## Illumina: starting from BCL files

```bash
nextflow run . -profile docker \
  --platform illumina --from_bcl true \
  --illumina_dir /path/to/run_folder \
  --dataset mydata --targets targets.bed --reference_fasta ref.fasta \
  --reference_snpeffdb Anopheles_gambiae
```

- `--illumina_dir` is the Illumina run folder, the one holding `SampleSheet.csv` and
  `Data/`. Give several run folders as a list in a params YAML file, and their samples
  are merged by `sample_id`.
- The sample metadata comes from the `[Data]` (or `[BCLConvert_Data]`) section of
  `SampleSheet.csv`, so that section must contain `sample_id` (or `Sample_ID`) and every
  cohort column. A `well` column (e.g. `A01`) is split into `well_letter`/`well_number`,
  and `plate_name` becomes `plate`.
- Merged FASTQs are written to `--reads_dir` (default `resources/reads`).
- The `bcl2fastq` image must be built locally first (see [Containers](#containers)).

## Parameters

Defaults are in [`nextflow.config`](../nextflow.config).

### Run

| Parameter | Default | Description |
|---|---|---|
| `--dataset` | `natcomms` | Dataset name, used in output file names. |
| `--platform` | `illumina` | `illumina` or `nanopore`. |
| `--ploidy` | `2` | Sample ploidy. Above 2 is Illumina only. |
| `--panel` | none | Set to `ag-vampir` for the *An. gambiae* species-ID and kdr notebooks. |
| `--cohort_columns` | `location,taxon,country` | Metadata columns used to group samples. |
| `--min_genotype_depth` | `10` | Nanopore: Clair3 genotypes below this depth become missing. |
| `--outdir` | `results` | Output folder. |

### Inputs

| Parameter | Default | Description |
|---|---|---|
| `--metadata` | – | Sample metadata TSV. Required unless `--from_bcl`. |
| `--from_bcl` | `false` | Illumina: demultiplex BCL run folders first. |
| `--illumina_dir` | – | Run folder(s) for `--from_bcl`. |
| `--reads_dir` | `resources/reads` | Where FASTQs are found (no fq1/fq2 columns) or written (`--from_bcl`). |
| `--metadata_colours` | – | Optional JSON of plot colours. |
| `--targets` | – | BED of target SNPs. Required. |
| `--reference_name` | – | Reference label. |
| `--reference_fasta` | – | Reference FASTA. Required. |
| `--reference_gff3` | – | GFF3, required with `--custom_snpeffdb true`. |
| `--reference_snpeffdb` | – | snpEff database name, required with `--custom_snpeffdb false`. |
| `--custom_snpeffdb` | `false` | Build the snpEff database from FASTA + GFF3. |
| `--clair3_model_path` | – | Nanopore: folder with the Clair3 PyTorch model. |

### QC and analysis switches

| Parameter | Default | Description |
|---|---|---|
| `--qc_fastp` | `true` | Include fastp/fastplong reports in MultiQC. |
| `--qc_coverage` | `true` | Illumina: mosdepth coverage and the coverage notebook. |
| `--qc_stats` | `true` | samtools flagstat and bcftools stats. |
| `--qc_multiqc` | `true` | MultiQC report. |
| `--qc_sample_min_mean_target_coverage` | `5` | Minimum mean target coverage for a sample to pass QC. |
| `--analysis_sample_map` | `false` | Map of samples (needs latitude/longitude). |
| `--analysis_population_structure` | `true` | PCA and neighbour-joining trees. |
| `--analysis_genetic_diversity` | `true` | Nucleotide diversity per cohort. |
| `--analysis_allele_frequencies` | `true` | Allele frequencies per cohort. |
| `--build_jupyter_book` | `true` | Build the HTML report. |

### Resources and containers

| Parameter | Default | Description |
|---|---|---|
| `--max_cpus` | `16` | Most CPUs any one step may use. |
| `--max_memory` | `128.GB` | Most memory any one step may use. |
| `--max_time` | `240.h` | Longest time any one step may run. |
| `--container_registry` | `ghcr.io/mishrap1971` | Registry of the pipeline-specific images. |
| `--container_tag` | `0.8` | Tag of the pipeline-specific images. |
| `--publish_dir_mode` | `copy` | How outputs are written to `--outdir` (`copy`, `symlink`, `link`, ...). |

## Resources and HPC

Each step asks for a fixed amount of CPU and memory (see
[`conf/base.config`](../conf/base.config)). `--max_cpus`, `--max_memory` and `--max_time`
cap those requests, so set them to what one machine or node can give:

```bash
--max_cpus 6  --max_memory 8.GB      # laptop
--max_cpus 48 --max_memory 108.GB    # large HPC node
```

Steps that run out of memory are retried a maximum of two times, first with double and then triple
memory, up to `--max_memory`. MultiQC and the cohort-wide notebooks (sample QC, SNP
tables, population structure, genetic diversity, allele frequencies) need more memory as
the number of samples grows. Large cohorts (300+ samples) may need 48 GB or
more.

To submit jobs through a scheduler instead of running on one machine, add a small config
file and pass it with `-c`:

```groovy
// slurm.config
process.executor = 'slurm'
process.queue    = 'normal'
```

```bash
nextflow run . -profile singularity -c slurm.config [parameters]
```

On HPC systems without Docker, use `-profile singularity`. Singularity converts the Docker
images on first use.

## Containers

Most tools come from BioContainers images, pinned in the modules and in
`conf/base.config`. Three images are specific to this pipeline:

| Image | Contents |
|---|---|
| `python` | papermill, Jupyter and the analysis libraries for the notebooks |
| `jupyterbook` | jupyter-book, for the HTML report |
| `bcl2fastq` | bcl2fastq, for `--from_bcl` |

`python` and `jupyterbook` are published at `ghcr.io/mishrap1971` for amd64 and arm64
and are pulled automatically.

`bcl2fastq` cannot be redistributed under Illumina's licence, so build it locally before a
`--from_bcl` run:

```bash
cd docker
./build.sh bcl2fastq                          # Intel/AMD Linux or Mac
PLATFORM=linux/amd64 ./build.sh bcl2fastq     # Apple Silicon (runs under emulation)
```

The image gets the same name the pipeline looks for
(`ghcr.io/mishrap1971/bcl2fastq:0.8`), so Docker uses the local copy. On Singularity
clusters, build it with Docker elsewhere and convert it, or point `--container_registry`
at a registry you control.

To build and use all three images yourself:

```bash
cd docker
CONTAINER_REGISTRY=myname ./build.sh
nextflow run . --container_registry myname [parameters]
```

## Troubleshooting common errors

- "Cannot connect to the Docker daemon": start Docker engine
- A step is killed (exit 137, or exit 138 for notebooks): Low memory. Raise
  `--max_memory`, or turn off the step (e.g. `--qc_multiqc false`) for very large cohorts.
- `FileNotFoundError ... pileup.pt`: the Clair3 model is a TensorFlow model. See
  [Clair3 models](#nanopore-clair3-models).
- "Not all provided cohort columns are present in the metadata file": check the metadata file,
  (or `SampleSheet.csv` for `--from_bcl`) which likely lacks a column named in `--cohort_columns`.
- A sample is missing from the analyses: check `config/metadata.qcpass.tsv`. Samples
  below `--qc_sample_min_mean_target_coverage`, and samples whose Clair3 run was skipped,
  are left out.
- bcl2fastq: "Too many open files": Docker runs get a higher open-file limit.
  With a Singularity engines, raise `ulimit -n` on the host.
- Each run writes a timeline, a resource report and a trace to `<outdir>/pipeline_info/`.
  The trace shows the exit code, memory and run time of every step.
