// sets Clair3 gVCF genotypes to missing (marked as ./.) where depth is below min_genotype_depth (default value = 10)
// Clair3 labels low-coverage and no-coverage calls as 0/0 instead of ./., to prevent being counted as wild type

process MASK_CLAIR3_GVCF {
    tag "${meta.id}/${meta.call_type}"
    label 'process_single'

    input:
    tuple val(meta), path(gvcf)
    val min_dp

    output:
    tuple val(meta), path("${meta.id}.calls.vcf"), emit: vcf

    script:
    """
    bcftools +setGT ${gvcf} -Ov -o ${meta.id}.calls.vcf -- \\
        -t q -n . -i '(FMT/MIN_DP<${min_dp}) | (FMT/DP<${min_dp})'
    """

    stub:
    """
    touch ${meta.id}.calls.vcf
    """
}
