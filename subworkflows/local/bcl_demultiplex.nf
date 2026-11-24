// Illumina BCL processing starting point: converts each run folder to FASTQ, merges them per sample, runs FastQC on the index reads.

include { BCL_CONVERT_RUN     } from '../../modules/local/bcl_convert_run'
include { BCL_MERGE_FASTQS    } from '../../modules/local/bcl_merge_fastqs'
include { FASTQC_INDEX_READS  } from '../../modules/local/fastqc_index_reads'

// wraps each list 
def wrapList(ch) {
    ch.map { v -> [ v instanceof List ? v : [ v ] ] }
}

workflow BCL_DEMULTIPLEX {

    take:
    illumina_dirs
    samples

    main:
    // one task per run folder.
    ch_runs = Channel.fromList(
        illumina_dirs.withIndex().collect { dir, i -> tuple(i.toString(), file(dir, checkIfExists: false)) }
    )

    BCL_CONVERT_RUN( ch_runs )

    ch_run_dirs = BCL_CONVERT_RUN.out.run_dir
        .map { run_id, dir -> dir }
        .collect()

    BCL_MERGE_FASTQS(
        params.dataset,
        ch_run_dirs,
        samples.map { it.id }.collect()
    )

    // select each sample's read 1 and read 2 files
    ch_reads = samples.combine( wrapList(BCL_MERGE_FASTQS.out.r1) ).combine( wrapList(BCL_MERGE_FASTQS.out.r2) )
        .map { meta, r1_list, r2_list ->
            def r1 = r1_list.find { it.name == "${meta.id}_1.fastq.gz" }
            def r2 = r2_list.find { it.name == "${meta.id}_2.fastq.gz" }
            tuple(meta, [ r1, r2 ])
        }

    ch_index_reads = BCL_MERGE_FASTQS.out.index1.map { f -> tuple([ id: 'I1' ], f) }
        .mix( BCL_MERGE_FASTQS.out.index2.map { f -> tuple([ id: 'I2' ], f) } )

    FASTQC_INDEX_READS( ch_index_reads )

    emit:
    reads             = ch_reads
    index_read_html   = FASTQC_INDEX_READS.out.report
    stats_json        = BCL_MERGE_FASTQS.out.stats_json
    demultiplex_stats = BCL_MERGE_FASTQS.out.demultiplex_stats
}
