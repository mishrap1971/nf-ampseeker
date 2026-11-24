// Reads the sample metadata (or Illumina sample sheet) into a table, assigns plot colours,
// and identifies FASTQ files corresponding to each sample and whether the metadata has plate/well columns

include { BUILD_METADATA   } from '../../modules/local/build_metadata'
include { METADATA_COLOURS } from '../../modules/local/metadata_colours'
include { cohortColumns; paramBoolean } from '../../lib/utils'

workflow INPUT_CHECK {

    take:
    illumina_dirs

    main:
    // build standard metadata table
    ch_metadata_inputs = paramBoolean(params.from_bcl)
        ? illumina_dirs.collect { file(it, checkIfExists: false) }
        : [ file(params.metadata, checkIfExists: false) ]

    BUILD_METADATA(
        params.dataset,
        paramBoolean(params.from_bcl) ? 'samplesheet' : 'metadata',
        ch_metadata_inputs,
        cohortColumns(params.cohort_columns)
    )
    ch_metadata = BUILD_METADATA.out.metadata

    // use the supplied colours file or generate colours from the cohort columns
    if ( params.metadata_colours ) {
        ch_colours = Channel.fromPath(params.metadata_colours, checkIfExists: false)
    } else {
        METADATA_COLOURS( ch_metadata, cohortColumns(params.cohort_columns) )
        ch_colours = METADATA_COLOURS.out.colours
    }

    // if the metadata has no fq1/fq2 columns, FASTQs are looked up in reads_dir as <sample_id>_1/_2.fastq.gz
    fastq_cols = params.platform == 'illumina' ? ['fq1', 'fq2'] : ['fq1']

    ch_flags = ch_metadata.map { tsv ->
        def header = tsv.readLines()[0].tokenize('\t') as Set
        if ( params.platform == 'nanopore' && !header.contains('fq1') ) {
            error "Metadata must contain an 'fq1' column pointing to FASTQ files for nanopore data."
        }
        [
            fastq_auto: !fastq_cols.every { header.contains(it) },
            plate_info: ['plate', 'well_letter', 'well_number'].every { header.contains(it) }
        ]
    }

    // one row per sample: sample list and reads
    ch_rows = ch_metadata.splitCsv(header: true, sep: '\t')

    ch_samples = ch_rows.map { row -> [ id: row.sample_id ] }

    ch_reads = ch_rows.combine(ch_flags).map { row, flags ->
        def meta  = [ id: row.sample_id ]
        def reads = fastq_cols.withIndex().collect { col, i ->
            flags.fastq_auto
                ? file("${params.reads_dir}/${meta.id}_${i + 1}.fastq.gz", checkIfExists: false)
                : file(row[col], checkIfExists: false)
        }
        tuple(meta, reads)
    }

    emit:
    metadata   = ch_metadata
    colours    = ch_colours
    samples    = ch_samples
    reads      = ch_reads
    fastq_auto = ch_flags.map { it.fastq_auto }
    plate_info = ch_flags.map { it.plate_info }
}
