// builds the sample metadata table, either from a user-supplied table (Nanopore or Illumina) or from Illumina sample sheets

process BUILD_METADATA {
    tag "$dataset"
    label 'process_single'

    input:
    val  dataset
    val  mode
    path inputs, stageAs: 'input_*'
    val  cohort_columns

    output:
    path "metadata.tsv", emit: metadata

    script:
    """
    build_metadata.py \\
        --mode ${mode} \\
        --inputs ${inputs} \\
        --cohort-columns ${cohort_columns.join(',')} \\
        --out metadata.tsv
    """

    stub:
    """
    printf "sample_id\\t${cohort_columns.join('\\t')}\\tfq1\\n" > metadata.tsv
    printf "sample1\\t${(['stub'] * cohort_columns.size()).join('\\t')}\\tstub\\n" >> metadata.tsv
    printf "sample2\\t${(['stub'] * cohort_columns.size()).join('\\t')}\\tstub\\n" >> metadata.tsv
    """
}
