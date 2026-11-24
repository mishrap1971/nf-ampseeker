// calls variants from a BAM with bcftools mpileup + call. Target calls are restricted to the BED regions; amplicon calls cover the whole amplicon

process BCFTOOLS_MPILEUP_CALL {
    tag "${meta.id}/${meta.call_type}"
    label 'process_low'

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta), path(fai)
    path ploidy_file
    path targets_bed

    output:
    tuple val(meta), path("*.calls.vcf"), emit: vcf

    script:
    def mpileup_args = task.ext.args ?: ''
    def regions       = meta.call_type == 'targets' ? "-R ${targets_bed}" : '-I'
    def call_extra    = meta.call_type == 'targets' ? '-f GQ,GP' : ''
    """
    bcftools mpileup -Ov ${mpileup_args} -f ${fasta} ${regions} -a AD --max-depth 2000 ${bam} |
    bcftools call ${call_extra} -m --ploidy-file ${ploidy_file} -Ov |
    bcftools sort -Ov -o ${meta.id}.calls.vcf
    """

    stub:
    """
    touch ${meta.id}.calls.vcf
    """
}
