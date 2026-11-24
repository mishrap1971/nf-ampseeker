// assigns a colour to each value of the cohort columns for consistency in plotting

process METADATA_COLOURS {
    label 'process_single'

    input:
    path metadata
    val  cohort_columns

    output:
    path "metadata_colours.json", emit: colours

    script:
    """
    metadata_colours.py \\
        --metadata ${metadata} \\
        --cohort-columns ${cohort_columns.join(',')} \\
        --out metadata_colours.json
    """

    stub:
    """
    printf '{}' > metadata_colours.json
    """
}
