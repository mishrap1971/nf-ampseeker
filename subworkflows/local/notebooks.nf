// runs the QC notebooks (run information, run statistics, reads per well, read QC, coverage, sample quality control)
// each call lists the files the notebook needs and the results/ layout it expects
// sample quality control produces the metadata of samples that pass QC

include { PAPERMILL_NOTEBOOK as PAPERMILL_RUN_INFORMATION        } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_RUN_STATISTICS         } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_READS_PER_WELL         } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_READ_QC                } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_COVERAGE               } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_SAMPLE_QUALITY_CONTROL } from '../../modules/local/papermill_notebook'
include { BUILD_CONFIG_SUMMARY                                   } from '../../modules/local/build_config_summary'
include { paramBoolean                                           } from '../../lib/utils'
include { wrapList                                                } from '../../lib/utils'
include { cohortColumns } from '../../lib/utils'
include { inputName                                               } from '../../lib/utils'
include { inputRef                                                } from '../../lib/utils'

workflow NOTEBOOKS {

    take:
    ch_metadata
    ch_colours
    ch_plate_info
    ch_fastp_json
    ch_bam
    ch_flagstat
    ch_per_base_bed
    ch_regions_bed
    ch_annot_targets
    ch_annot_amplicons
    ch_demultiplex_stats

    main:
    ch_lib = file("${projectDir}/assets/notebooks/lib")
    def dataset = params.dataset
    def platform = params.platform
    def cohort_cols = cohortColumns(params.cohort_columns).join(',')
    def from_bcl = paramBoolean(params.from_bcl)

    def metadata    = ch_metadata.first()
    def colours     = ch_colours.first()
    def targets     = ch_annot_targets.first()
    def amplicons   = ch_annot_amplicons.first()
    def plate_info  = ch_plate_info.first()
    def ch_bed      = Channel.value( file(params.targets, checkIfExists: false) )

    // run information: reference settings (use empty text when a setting isn't used, since process inputs can't be null)
    BUILD_CONFIG_SUMMARY( params.reference_name ?: dataset, params.reference_fasta, params.reference_gff3 ?: '', params.reference_snpeffdb ?: '' )
    PAPERMILL_RUN_INFORMATION(
        metadata.combine(ch_bed).combine(BUILD_CONFIG_SUMMARY.out.yaml)
            .map { meta_f, bed_f, config_f ->
                def files = [ meta_f, bed_f, config_f ]
                tuple(
                    'run-information',
                    file("${projectDir}/assets/notebooks/run-information.ipynb"),
                    files, [:],
                    [
                        config_path: inputRef(files, config_f), metadata_path: inputRef(files, meta_f),
                        bed_targets_path: inputRef(files, bed_f), panel: (params.panel ?: ''),
                        dataset: dataset, platform: platform, cohort_cols: cohort_cols, wkdir: '.',
                    ]
                )
            },
        ch_lib
    )

    // notebooks that only run under some settings are added to this list as they are created
    ch_notebooks = Channel.empty()

    // run statistics for when input is BCL
    if ( platform == 'illumina' && from_bcl ) {
        PAPERMILL_RUN_STATISTICS(
            metadata.combine(ch_demultiplex_stats.first()).combine(colours).combine(plate_info)
                .map { meta_f, stats_f, colours_f, has_plate_info ->
                    def files = [ meta_f, stats_f, colours_f ]
                    tuple(
                        'run-statistics',
                        file("${projectDir}/assets/notebooks/run-statistics.ipynb"),
                        files,
                        [
                            'resources/reads/Stats/Stats.json':      inputName(files, stats_f),
                            'results/config/metadata_colours.json': inputName(files, colours_f),
                        ],
                        [
                            plate_info: has_plate_info, metadata_path: inputRef(files, meta_f),
                            cohort_cols: cohort_cols, wkdir: '.',
                        ]
                    )
                },
            ch_lib
        )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_RUN_STATISTICS.out.notebook.map { n, f -> f } )
    }

    // reads per well, only runs when the metadata has plate/well column
    def ch_bam_files = ch_bam.map { m, bam, bai -> [ bam, bai ] }.flatten().collect().map { wrapList(it) }
    def ch_flagstats = ch_flagstat.map { m, f -> f }.collect().map { wrapList(it) }
    PAPERMILL_READS_PER_WELL(
        plate_info.filter { it }.combine(metadata).combine(ch_bam_files).combine(ch_flagstats)
            .map { has_plate_info, meta_f, bams, flagstats ->
                def files = bams + flagstats + [ meta_f ]
                def stage_paths = [:]
                bams.each      { f -> stage_paths["results/alignments/${f.name}"]          = inputName(files, f) }
                flagstats.each { f -> stage_paths["results/alignments/bamStats/${f.name}"] = inputName(files, f) }
                tuple(
                    'reads-per-well',
                    file("${projectDir}/assets/notebooks/reads-per-well.ipynb"),
                    files, stage_paths,
                    [ wkdir: '.', metadata_path: inputRef(files, meta_f) ]
                )
            },
        ch_lib
    )

    // read QC from the fastp reports
    PAPERMILL_READ_QC(
        metadata.combine( ch_fastp_json.collect().map { wrapList(it) } )
            .map { meta_f, jsons ->
                def files = jsons + [ meta_f ]
                def stage_paths = [:]
                jsons.each { f -> stage_paths["results/qc/fastp_reports/${f.name}"] = inputName(files, f) }
                tuple(
                    'read-quality',
                    file("${projectDir}/assets/notebooks/read-quality.ipynb"),
                    files, stage_paths,
                    [ metadata_path: inputRef(files, meta_f), index_read_qc: from_bcl, wkdir: '.' ]
                )
            },
        ch_lib
    )

    // coverage plots from the mosdepth output
    if ( paramBoolean(params.qc_coverage) ) {
        PAPERMILL_COVERAGE(
            metadata.combine(ch_bed)
                .combine( ch_per_base_bed.map { m, f -> f }.collect().ifEmpty([]).map { wrapList(it) } )
                .combine( ch_regions_bed.map { m, f -> f }.collect().ifEmpty([]).map { wrapList(it) } )
                .map { meta_f, bed_f, per_base_files, region_files ->
                    def files = per_base_files + region_files + [ meta_f, bed_f ]
                    def stage_paths = [:]
                    per_base_files.each { f -> stage_paths["results/coverage/${f.name}"] = inputName(files, f) }
                    region_files.each  { f -> stage_paths["results/coverage/${f.name}"] = inputName(files, f) }
                    tuple(
                        'coverage',
                        file("${projectDir}/assets/notebooks/coverage.ipynb"),
                        files, stage_paths,
                        [ metadata_path: inputRef(files, meta_f), bed_targets_path: inputRef(files, bed_f), wkdir: '.' ]
                    )
                },
            ch_lib
        )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_COVERAGE.out.notebook.map { n, f -> f } )
    }

    // sample quality control. flags low coverage, high heterozygosity and outlier samples and writes metadata.qcpass.tsv.
    PAPERMILL_SAMPLE_QUALITY_CONTROL(
        metadata.combine(ch_bed).combine(targets).combine(amplicons).combine(colours)
            .combine( ch_per_base_bed.map { m, f -> f }.collect().ifEmpty([]).map { wrapList(it) } )
            .combine( ch_regions_bed.map { m, f -> f }.collect().ifEmpty([]).map { wrapList(it) } )
            .map { meta_f, bed_f, targets_f, amplicons_f, colours_f, per_base_files, region_files ->
                def files = per_base_files + region_files + [ meta_f, bed_f, targets_f, amplicons_f, colours_f ]
                def stage_paths = [
                    "results/vcfs/targets/${dataset}.annot.vcf": inputName(files, targets_f),
                    "results/vcfs/amplicons/${dataset}.annot.vcf": inputName(files, amplicons_f),
                    "results/config/metadata_colours.json": inputName(files, colours_f),
                ]
                per_base_files.each { f -> stage_paths["results/coverage/${f.name}"] = inputName(files, f) }
                region_files.each  { f -> stage_paths["results/coverage/${f.name}"] = inputName(files, f) }
                tuple(
                    'sample-quality-control',
                    file("${projectDir}/assets/notebooks/sample-quality-control.ipynb"),
                    files, stage_paths,
                    [
                        platform: platform, dataset: dataset, panel: (params.panel ?: ''),
                        metadata_path: inputRef(files, meta_f), cohort_cols: cohort_cols,
                        bed_targets_path: inputRef(files, bed_f), vcf_path: "results/vcfs/targets/${dataset}.annot.vcf",
                        wkdir: '.', sample_min_mean_target_coverage: params.qc_sample_min_mean_target_coverage,
                    ]
                )
            },
        ch_lib
    )

    emit:
    metadata_qcpass = PAPERMILL_SAMPLE_QUALITY_CONTROL.out.extra_tsv
    notebooks = ch_notebooks
        .mix( PAPERMILL_RUN_INFORMATION.out.notebook.map { n, f -> f } )
        .mix( PAPERMILL_READS_PER_WELL.out.notebook.map { n, f -> f } )
        .mix( PAPERMILL_READ_QC.out.notebook.map { n, f -> f } )
        .mix( PAPERMILL_SAMPLE_QUALITY_CONTROL.out.notebook.map { n, f -> f } )
}
