// With bcl2fastq, converts input Illumina run folder consisting of raw BCL files to FASTQ

process BCL_CONVERT_RUN {
    tag "$run_id"
    label 'process_medium'

    input:
    tuple val(run_id), path(illumina_dir)

    output:
    tuple val(run_id), path("bcl_runs/${run_id}"), emit: run_dir

    script:
    """
    mkdir -p bcl_runs/${run_id}
    bcl2fastq \\
        --runfolder-dir ${illumina_dir} \\
        --output-dir bcl_runs/${run_id} \\
        --sample-sheet ${illumina_dir}/SampleSheet.csv
    """

    stub:
    """
    mkdir -p bcl_runs/${run_id}/Stats
    touch bcl_runs/${run_id}/Stats/Stats.json
    touch bcl_runs/${run_id}/Stats/DemultiplexingStats.xml
    """
}
