// drops gVCF reference blocks and the <NON_REF> allele from a merged gVCF, leaving a normal VCF.
// the input is staged as input.vcf so the output (<dataset>.merged.vcf, same name as the input) never overwrites it.

process BCFTOOLS_DROP_NON_REF {
    tag "${meta.id}/${meta.call_type}"
    label 'process_single'

    input:
    tuple val(meta), path(vcf, stageAs: 'input.vcf')

    output:
    tuple val(meta), path("${meta.id}.merged.vcf"), emit: vcf

    script:
    """
    bcftools view -a -i 'ALT!="<NON_REF>"' -Ov -o ${meta.id}.merged.vcf ${vcf}
    """

    stub:
    """
    touch ${meta.id}.merged.vcf
    """
}
