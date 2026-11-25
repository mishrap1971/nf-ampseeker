# Output

Everything is written under `--outdir` (default `results/`). `<dataset>` is the value of
`--dataset`. `targets` means the target SNP positions in the BED file. `amplicons` means
every position across the amplified regions.

## Report

| Path | Contents |
|---|---|
| `ampseeker-results/_build/html/index.html` | The HTML report. Open it in a browser; it links to the notebooks, the MultiQC report and the result files. |
| `notebooks/` | The executed notebooks (`.ipynb`) behind the report. `notebooks/ag-vampir/` holds the species-ID and kdr notebooks. |

## Sample information

| Path | Contents |
|---|---|
| `config/metadata.tsv` | The sample table the run used. |
| `config/metadata.qcpass.tsv` | Samples that passed QC. Only these are used in the analyses. |
| `config/metadata_colours.json` | Plot colours for each cohort value. |
| `config/bcftools_ploidy.txt` | Ploidy file passed to bcftools. |

## Reads and alignments

| Path | Contents |
|---|---|
| `trimmed-reads/` | Trimmed FASTQs from fastp (Illumina) or fastplong (nanopore). |
| `alignments/<sample>.bam`, `.bam.bai` | Sorted, indexed alignments. |
| `alignments/bamStats/` | `samtools flagstat` per sample. |
| `coverage/` | mosdepth coverage per sample, plus `amplicon_by_sample_depth.xlsx` (depth per amplicon and sample). |

## Variants

`vcfs/targets/` and `vcfs/amplicons/` hold:

| File | Contents |
|---|---|
| `<sample>.calls.vcf` | Calls for one sample. |
| `<dataset>.merged.vcf` | All samples merged. |
| `<dataset>.annot.vcf` | Merged calls annotated by snpEff. **The main result file.** |
| `<dataset>-snps.xlsx` | Annotated SNPs as a spreadsheet. |

For nanopore amplicons, `vcfs/amplicons/<sample>.clair3.g.vcf.gz` is the raw Clair3 gVCF,
and `<sample>.calls.vcf` is the same file with low-depth genotypes set to missing.

`vcfs/annotations/` holds the snpEff database that was built or downloaded.

## Analysis results

| Path | Contents |
|---|---|
| `snp_frequencies_summary.tsv` | Allele frequency of each SNP per cohort, with its snpEff annotation. |
| `allele_frequencies_<cohort>.png` | Allele-frequency heatmaps, one per cohort column. |
| `genetic-diversity/<cohort>.pi.tsv` | Nucleotide diversity (π) per cohort value, and per sample in `samples.pi.tsv`. |
| `njt_<cohort>.png` | Neighbour-joining trees coloured by cohort column. |

## QC

| Path | Contents |
|---|---|
| `qc/multiqc/multiqc_report.html` | MultiQC report across all samples. |
| `qc/fastp_reports/` | Per-sample trimming reports (`<sample>.html`, `.json`). |
| `qc/<dataset>-<targets\|amplicons>.merged.vcf.bcftools_stats.txt` | bcftools stats for the merged VCFs. |
| `qc/index-read-qc/` | `--from_bcl` only: FastQC of the index reads. |

## Run information

| Path | Contents |
|---|---|
| `pipeline_info/` | Nextflow timeline, resource report, trace and DAG, time-stamped per run. |

Folders such as `bwa_index/`, `samtools_faidx/` and `build_config_summary/` hold reference
indexes and other intermediate files.

The run also copies the executed notebooks to `docs/ampseeker-results/notebooks/` inside
the folder you launched it from. You can delete that copy.
