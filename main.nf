#!/usr/bin/env nextflow
// AmpSeeker: amplicon sequencing analysis (Nextflow version, ported from the original Snakemake-based AmpSeeker workflow).
// Maps reads, calls variants, annotates them, runs QC and analysis notebooks, and builds an HTML report.


nextflow.enable.dsl = 2

include { paramBoolean } from './lib/utils'
include { cohortColumns } from './lib/utils'

// Prints usage when --help is given.
def helpMessage() {
    log.info """
    Usage:
      nextflow run . -profile docker --metadata metadata.tsv --targets panel.bed \\
        --reference_fasta ref.fa --reference_gff3 ref.gff --dataset mydata

      nextflow run . -profile test,docker            # minimal test dataset
      nextflow run . -params-file params.yaml        # supply all params as YAML

    Required:
      --dataset             Dataset name, used in output filenames
      --targets             BED file of target loci
      --reference_fasta     Reference genome FASTA
      --metadata            Sample metadata TSV  (unless --from_bcl)
      --illumina_dir        Illumina run dir(s)  (only when --from_bcl)

    Key options:
      --platform            illumina | nanopore              [${params.platform}]
      --ploidy              1 | 2 | >2 (illumina only)       [${params.ploidy}]
      --panel               e.g. ag-vampir                   [${params.panel}]
      --from_bcl            Demultiplex BCL to FASTQ first   [${params.from_bcl}]
      --custom_snpeffdb     Build snpEff db from fasta+gff    [${params.custom_snpeffdb}]
      --outdir              Output directory                  [${params.outdir}]

    See nextflow.config for the full parameter list.
    """.stripIndent()
}

// Stops early with a clear message if the parameter combination is invalid; returns the Illumina run folders.
def validateParams() {

    if ( !(params.platform in ['illumina','nanopore']) ) {
        error "Unsupported platform '${params.platform}'. Use 'illumina' or 'nanopore'."
    }

    def ploidy
    try {
        ploidy = params.ploidy as Integer
    } catch (Exception e) {
        error "ploidy must be a positive integer, got '${params.ploidy}'."
    }
    if ( ploidy < 1 ) {
        error "ploidy must be >= 1, got ${ploidy}."
    }
    if ( params.platform == 'nanopore' && ploidy > 2 ) {
        error "Polyploid (ploidy > 2) is not supported for nanopore data.\n" +
              "Use Illumina for polyploid organisms, or set ploidy to 1 or 2."
    }
    if ( !(params.min_genotype_depth.toString().isInteger()) || (params.min_genotype_depth as Integer) < 0 ) {
        error "min_genotype_depth must be a non-negative integer, got '${params.min_genotype_depth}'."
    }

    def from_bcl = paramBoolean(params.from_bcl)
    def custom_snpeffdb = paramBoolean(params.custom_snpeffdb)

    if ( params.platform == 'nanopore' && from_bcl ) {
        error "--from_bcl is only compatible with Illumina data. Set from_bcl = false for nanopore."
    }
    if ( params.platform == 'nanopore' && !params.metadata ) {
        error "A metadata file must be provided for nanopore data (--metadata), " +
              "and must contain an 'fq1' column pointing to FASTQ files."
    }
    if ( params.platform == 'illumina' && !from_bcl && !params.metadata ) {
        error "When from_bcl is false, a metadata file must be provided (--metadata)."
    }

    def illumina_dirs = ( params.illumina_dir instanceof List )
        ? params.illumina_dir.findAll { it instanceof String && it }
        : ( params.illumina_dir ? [ params.illumina_dir ] : [] )

    if ( params.platform == 'illumina' && from_bcl && illumina_dirs.isEmpty() ) {
        error "When from_bcl is true, --illumina_dir must be provided (single path or list of paths)."
    }

    if ( !params.targets )         error "--targets (BED file of target loci) is required."

    // The ag-vampir notebooks only recognise contigs named 2L/2R/3L/3R/X, so reject prefixed names (e.g. AgamP4_2L)
    if ( params.panel == 'ag-vampir' && params.targets ) {
        def bed = file(params.targets)
        if ( bed.exists() ) {
            def contigs = bed.readLines().findAll { it && !it.startsWith('#') }.collect { it.tokenize('\t')[0] } as Set
            if ( !contigs.any { it in ['2L', '2R', '3L', '3R', 'X'] } ) {
                error "panel 'ag-vampir' needs bare contig names (2L, 2R, 3L, 3R, X) in the targets BED, " +
                      "but ${params.targets} has: ${contigs.take(5).join(', ')}...\n" +
                      "The species-id and kdr-analysis notebooks hard-code those names, Strip any prefix " +
                      "(e.g. 'AgamP4_') from the reference FASTA, GFF and BED consistently"
            }
        }
    }
    if ( !params.reference_fasta ) error "--reference_fasta is required."
    if ( custom_snpeffdb && !params.reference_gff3 ) {
        error "--reference_gff3 is required when custom_snpeffdb is true."
    }
    if ( !custom_snpeffdb && !params.reference_snpeffdb ) {
        error "--reference_snpeffdb is required unless custom_snpeffdb is true."
    }

    return illumina_dirs
}

// One-line description of where the reads come from, for the banner.
def input_description(dirs) {
    if ( params.platform == 'illumina' && paramBoolean(params.from_bcl) )
        return "Illumina BCL folders: ${dirs.join(', ')}"
    if ( params.platform == 'illumina' )
        return "FASTQ paths from metadata (fq1/fq2, auto-detected from sample_id if absent)"
    return "Nanopore FASTQ path from metadata (fq1, auto-detected from sample_id if absent)"
}

// Prints the run summary at startup.
def printBanner(dirs) {
    log.info """
------------------------------------------------------------------------
  A m p S e e k e r   ${params.version}
------------------------------------------------------------------------
  Dataset          : ${params.dataset}
  Platform         : ${params.platform}
  Panel            : ${params.panel ?: 'none'}
  Ploidy           : ${params.ploidy}
  Input            : ${input_description(dirs)}
  Reference        : ${params.reference_fasta}
  Targets          : ${params.targets}
  Cohort columns   : ${cohortColumns(params.cohort_columns).join(', ')}
  Output dir       : ${params.outdir}
  Profile(s)       : ${workflow.profile}
------------------------------------------------------------------------
""".stripIndent()
}

// Subworkflows and modules used by the main workflow.
include { INPUT_CHECK           } from './subworkflows/local/input_check'
include { BCL_DEMULTIPLEX       } from './subworkflows/local/bcl_demultiplex'
include { MAP_CALL_ILLUMINA     } from './subworkflows/local/map_call_illumina'
include { MAP_CALL_NANOPORE     } from './subworkflows/local/map_call_nanopore'
include { MERGE_CALLS           } from './subworkflows/local/merge_calls'
include { QUALITY_CONTROL       } from './subworkflows/local/quality_control'
include { SAMTOOLS_FAIDX        } from './modules/nf-core/samtools/faidx/main'
include { CREATE_PLOIDY_FILE    } from './modules/local/create_ploidy_file'
include { ANNOTATE              } from './subworkflows/local/annotate'
include { ANALYSIS              } from './subworkflows/local/analysis'
include { NOTEBOOKS             } from './subworkflows/local/notebooks'
include { SNP_DATAFRAME         } from './subworkflows/local/snp_dataframe'
include { AG_VAMPIR             } from './subworkflows/local/ag_vampir'
include { REPORT                } from './subworkflows/local/report'

// Main pipeline: input check -> map and call variants -> merge -> annotate -> QC -> notebooks -> report.
workflow AMPSEEKER {

    take:
    illumina_dirs

    main:
    // Read the sample metadata, work out where the FASTQs are and pick plot colours.
    INPUT_CHECK( illumina_dirs )

    ch_metadata   = INPUT_CHECK.out.metadata
    ch_colours    = INPUT_CHECK.out.colours
    ch_samples    = INPUT_CHECK.out.samples
    ch_plate_info = INPUT_CHECK.out.plate_info

    // Demultiplex raw BCL runs into FASTQs when starting from sequencer output.
    if ( paramBoolean(params.from_bcl) ) {
        BCL_DEMULTIPLEX( illumina_dirs, ch_samples )
        ch_reads             = BCL_DEMULTIPLEX.out.reads
        // run-statistics.ipynb reads bcl2fastq's Stats/Stats.json (not DemultiplexingStats.xml)
        ch_demultiplex_stats = BCL_DEMULTIPLEX.out.stats_json
    } else {
        ch_reads             = INPUT_CHECK.out.reads
        ch_demultiplex_stats = Channel.empty()
    }

    // Reference index and ploidy file, shared by every sample (.first() lets all samples reuse them).
    ch_fasta = Channel.value( tuple([ id: params.reference_name ?: params.dataset ], file(params.reference_fasta, checkIfExists: false)) )
    SAMTOOLS_FAIDX( ch_fasta.map { meta, fa -> tuple(meta, fa, []) }, false )
    ch_fasta_fai = SAMTOOLS_FAIDX.out.fai.first()

    CREATE_PLOIDY_FILE( params.ploidy )
    ch_ploidy = CREATE_PLOIDY_FILE.out.ploidy_file.first()

    def ch_targets_bed = file(params.targets, checkIfExists: false)

    // Trim, align and call variants: bwa + bcftools for Illumina, minimap2 + bcftools/Clair3 for nanopore.
    if ( params.platform == 'illumina' ) {
        MAP_CALL_ILLUMINA( ch_reads, ch_fasta, ch_fasta_fai, ch_targets_bed, ch_ploidy )
        ch_bam        = MAP_CALL_ILLUMINA.out.bam
        ch_calls_raw  = MAP_CALL_ILLUMINA.out.calls
        ch_fastp_json = MAP_CALL_ILLUMINA.out.fastp_json
    } else {
        MAP_CALL_NANOPORE( ch_reads, ch_fasta, ch_fasta_fai, ch_targets_bed, ch_ploidy )
        ch_bam        = MAP_CALL_NANOPORE.out.bam
        ch_calls_raw  = MAP_CALL_NANOPORE.out.calls
        ch_fastp_json = MAP_CALL_NANOPORE.out.fastp_json
    }

    // Merge the per-sample calls into one VCF per call type.
    // nanopore amplicon gVCFs are merged against the reference (bcftools merge -g), which needs the fasta and its index
    MERGE_CALLS( ch_calls_raw, ch_fasta.combine( ch_fasta_fai.map { m, fai -> fai } ).map { m, fasta, fai -> tuple(m, fasta, fai) }.first() )
    ch_merged_vcf = MERGE_CALLS.out.merged_vcf

    // Annotate variant effects with snpEff.
    ch_gff3 = file(params.reference_gff3, checkIfExists: false)
    ANNOTATE( ch_merged_vcf, ch_fasta, ch_gff3 )
    ch_annotated_vcf = ANNOTATE.out.vcf

    // Coverage, mapping and variant statistics, plus the MultiQC report.
    QUALITY_CONTROL( ch_bam, ch_fastp_json, ch_merged_vcf.map { meta, vcf -> tuple(meta, vcf, []) }, ch_targets_bed )

    // Split the annotated VCFs by call type, then run the QC notebooks.
    ch_annot_targets   = ch_annotated_vcf.filter { meta, vcf -> meta.call_type == 'targets'   }.map { meta, vcf -> vcf }
    ch_annot_amplicons = ch_annotated_vcf.filter { meta, vcf -> meta.call_type == 'amplicons' }.map { meta, vcf -> vcf }

    NOTEBOOKS(
        ch_metadata, ch_colours, ch_plate_info, ch_fastp_json, ch_bam,
        QUALITY_CONTROL.out.flagstat, QUALITY_CONTROL.out.per_base_bed, QUALITY_CONTROL.out.regions_bed,
        ch_annot_targets, ch_annot_amplicons, ch_demultiplex_stats
    )

    // Exports SNPs to spreadsheets. With the ag-vampir panel, also run species ID and kdr analysis;
    // the analysis notebooks then use the metadata and colours updated with the species call.
    SNP_DATAFRAME( ch_annot_targets, ch_annot_amplicons )
    if ( params.panel == 'ag-vampir' ) {
        AG_VAMPIR( NOTEBOOKS.out.metadata_qcpass, ch_colours, ch_annot_targets, ch_annot_amplicons, SNP_DATAFRAME.out.targets_xlsx )
        ch_qcpass_final  = AG_VAMPIR.out.metadata_qcpass
        ch_colours_final = AG_VAMPIR.out.colours
        ch_agv_notebooks = AG_VAMPIR.out.notebooks
    } else {
        ch_qcpass_final  = NOTEBOOKS.out.metadata_qcpass
        ch_colours_final = ch_colours
        ch_agv_notebooks = Channel.empty()
    }
    ANALYSIS( ch_qcpass_final, ch_colours_final, ch_annot_targets, ch_annot_amplicons )

    // Build the HTML report from all executed notebooks.
    if ( paramBoolean(params.build_jupyter_book) ) {
        REPORT( NOTEBOOKS.out.notebooks.mix( ANALYSIS.out.notebooks ).mix( SNP_DATAFRAME.out.notebooks ).mix( ch_agv_notebooks ) )
    }
}

workflow {
    if ( params.help ) {
        helpMessage()
        exit 0
    }

    // Entry point: validate parameters, print the banner, run the pipeline (or show help).
    def illumina_dirs = validateParams()
    printBanner(illumina_dirs)

    AMPSEEKER( illumina_dirs )
}
