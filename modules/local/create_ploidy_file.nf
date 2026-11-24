// writes the ploidy file that bcftools call needs

process CREATE_PLOIDY_FILE {
    label 'process_single'

    input:
    val ploidy

    output:
    path "bcftools_ploidy.txt", emit: ploidy_file

    script:
    """
    printf '* * * M %s\\n' ${ploidy} >  bcftools_ploidy.txt
    printf '* * * F %s\\n' ${ploidy} >> bcftools_ploidy.txt
    """

    stub:
    """
    touch bcftools_ploidy.txt
    """
}
