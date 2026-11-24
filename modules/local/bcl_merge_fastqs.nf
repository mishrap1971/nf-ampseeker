// merges the FASTQs from all demultiplexed Illumina runs into one pair of files per sample, retains index reads and demultiplexing stats

process BCL_MERGE_FASTQS {
    tag "$dataset"
    label 'process_single'

    input:
    val  dataset
    path run_dirs, stageAs: 'bcl_runs_*'
    val  sample_ids

    output:
    path "*_1.fastq.gz", emit: r1
    path "*_2.fastq.gz", emit: r2
    path "I1_combined.fastq.gz", emit: index1, optional: true
    path "I2_combined.fastq.gz", emit: index2, optional: true
    path "Stats/Stats.json", emit: stats_json
    path "Stats/DemultiplexingStats.xml", emit: demultiplex_stats

    script:
    """
    bcl_merge_fastqs.py \\
        --run-dirs ${run_dirs} \\
        --samples ${sample_ids.join(',')} \\
        --outdir .
    """

    stub:
    """
    mkdir -p Stats
    ${sample_ids.collect { "touch ${it}_1.fastq.gz ${it}_2.fastq.gz" }.join('\n    ')}
    touch I1_combined.fastq.gz I2_combined.fastq.gz
    touch Stats/Stats.json Stats/DemultiplexingStats.xml
    """
}
