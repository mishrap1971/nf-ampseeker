# AmpSeeker 2.0 (Nextflow)

AmpSeeker analyses amplicon sequencing data from Illumina or Oxford Nanopore. It maps
reads to a reference, calls and annotates variants, runs sample QC, and performs population genetics analysis. All these steps are summarised an HTML report that includes coverage, population structure, genetic diversity and allele-frequency results.

This is a Nextflow DSL2 version of
[AmpSeeker](https://github.com/sanjaynagi/AmpSeeker). It uses the same inputs, analysis notebooks and output layout. The workflow can be run in a Docker or Singularity container.

## What it does

| Step | Illumina | Nanopore |
|---|---|---|
| Demultiplex (optional) | bcl2fastq from BCL run folders | – |
| Trim reads | fastp | fastplong |
| Map | bwa mem | minimap2 |
| Call variants at target SNPs | bcftools mpileup/call | bcftools mpileup/call |
| Call variants across amplicons | bcftools mpileup/call | Clair3 (gVCF, low-depth genotypes set to missing) |
| Merge samples, annotate | bcftools merge, snpEff | bcftools merge, snpEff |
| QC | mosdepth, samtools flagstat, bcftools stats, MultiQC, QC notebooks | same (no mosdepth) |
| Analysis | population structure, genetic diversity, allele frequencies, SNP tables | same |
| Report | jupyter-book HTML | jupyter-book HTML |

The `ag-vampir` panel also runs the *An. gambiae* species-ID and kdr notebooks.

## Installation

You need Java v17 or later, [Nextflow](https://www.nextflow.io/) 24.04+ and Docker or
Singularity/Apptainer. You do not need to install any bioinformatics tool that is used in the workflow, they run in a container that is pulled by the pipeline.

**1. Java 17 or newer.** Check with `java -version`. To install it:

```bash
curl -s https://get.sdkman.io | bash
```

```bash
sdk install java 17.0.10-tem
```

**2. Nextflow.**

```bash
curl -s https://get.nextflow.io | bash
```

```bash
chmod +x nextflow && mkdir -p ~/bin && mv nextflow ~/bin/
```

Make sure `~/bin` is on your `PATH`, then check with `nextflow -version`.
`conda install -c bioconda nextflow` works too.

**3. A container engine.**

- Laptop or PC: [Docker](https://docs.docker.com/get-docker/). On a Mac, give
  Docker Desktop at least 8 GB of memory (Settings → Resources). Check that Docker is running
  with `docker info`.
- HPC: Check with your server admin. Most HPCs use Singularity/Apptainer, usually already installed (`module load singularity`, or `apptainer --version`). Use `-profile singularity` instead of `-profile docker` in every command. In case your HPC has Docker configured, stick with `-profile docker`

**4. AmpSeeker pipeline.** 

Fetch the pipeline through Nextflow:
```bash
nextflow pull mishrap1971/nf-ampseeker
```

If you want to customise the config settings, clone it from github:

```bash
git clone https://github.com/mishrap1971/nf-ampseeker.git
```

**5. Check the install.** This is a dry run of the whole workflow with placeholder steps (needs no
data):

```bash
nextflow run mishrap1971/nf-ampseeker -r main -profile test,docker -stub
```

It should end with `[SUCCESS]`.

**6. Extra downloads**

- Nanopore: a Clair3 PyTorch model, a folder with `pileup.pt` and `full_alignment.pt`. See
  [Clair3 models](docs/usage.md#nanopore-clair3-models).
- Illumina from BCL (`--from_bcl`): the `bcl2fastq` image. Illumina's licence forbids
  sharing it, so it has to be built locally (on Apple Silicon, put `PLATFORM=linux/amd64`
  before `./build.sh`):

  ```bash
  git clone https://github.com/mishrap1971/nf-ampseeker.git
  cd nf-ampseeker/docker && ./build.sh bcl2fastq
  ```

More on the containers: [Containers](docs/usage.md#containers).

## Quick start

Nanopore:

```bash
nextflow run mishrap1971/nf-ampseeker -r main -profile docker \
  --dataset mydata \
  --platform nanopore \
  --metadata metadata.tsv \
  --targets targets.bed \
  --reference_fasta ref.fasta \
  --reference_gff3 ref.gff \
  --custom_snpeffdb true \
  --clair3_model_path clair3_models/r1041_e82_400bps_sup_v420 \
  --outdir results
```

Illumina, from FASTQ:

```bash
nextflow run mishrap1971/nf-ampseeker -r main -profile docker \
  --dataset mydata \
  --platform illumina \
  --metadata metadata.tsv \
  --targets targets.bed \
  --reference_fasta ref.fasta \
  --reference_snpeffdb Anopheles_gambiae \
  --outdir results
```

If running on a laptop, add limits that fit the machine's CPU limits, e.g., `--max_cpus 6 --max_memory 8.GB`.
Open `results/ampseeker-results/_build/html/index.html` when the run finishes.

`metadata.tsv` is tab-separated, with one row per sample:

```tsv
sample_id	location	taxon	country	fq1	fq2
S1	Kisumu	funestus	Kenya	/data/S1_R1.fastq.gz	/data/S1_R2.fastq.gz
```

Leave out `fq2` for nanopore.

## Documentation

- [Usage](docs/usage.md): inputs, all parameters, Clair3 models, BCL runs, HPC settings,
  troubleshooting
- [Output](docs/output.md): what each output folder holds

## Credits

AmpSeeker was written by Sanjay C. Nagi and contributors
([sanjaynagi/AmpSeeker](https://github.com/sanjaynagi/AmpSeeker)). The analysis
notebooks and their Python helpers come from that repository. The Nextflow version is by
Prashastha Mishra. If you use this pipeline, please cite the original AmpSeeker
repository and the tools it runs.
