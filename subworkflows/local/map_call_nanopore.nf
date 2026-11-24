// Nanopore branch: trim reads (fastplong), align (minimap2), index the BAMs, call target variants with bcftools and whole-amplicon variants with Clair3
// Clair3 runs in gVCF mode and is depth-masked, so samples with no data stay missing (./.) after merging instead of counting as wild type

include { FASTPLONG                          } from '../../modules/nf-core/fastplong/main'
include { MINIMAP2_INDEX                     } from '../../modules/nf-core/minimap2/index/main'
include { MINIMAP2_ALIGN                     } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_INDEX                     } from '../../modules/nf-core/samtools/index/main'
include { BCFTOOLS_MPILEUP_CALL              } from '../../modules/local/bcftools_mpileup_call'
include { CLAIR3                             } from '../../modules/nf-core/clair3/main'
include { MASK_CLAIR3_GVCF                   } from '../../modules/local/mask_clair3_gvcf'

workflow MAP_CALL_NANOPORE {

    take:
    ch_reads
    ch_fasta
    ch_fasta_fai
    targets_bed
    ploidy_file

    main:
    // trim and filter the long reads
    FASTPLONG( ch_reads.map { meta, reads -> tuple(meta, reads[0]) }, [], false, false )

    // index the reference and align each sample
    MINIMAP2_INDEX( ch_fasta )

    ch_minimap2_idx = ch_fasta.combine( MINIMAP2_INDEX.out.index.map { m, idx -> idx } ).map { m, fa, idx -> tuple(m, idx) }.first()

    MINIMAP2_ALIGN( FASTPLONG.out.reads, ch_minimap2_idx, true, 'bai', false, false )

    SAMTOOLS_INDEX( MINIMAP2_ALIGN.out.bam )

    // BAM + index each sample
    ch_bam = MINIMAP2_ALIGN.out.bam.join( SAMTOOLS_INDEX.out.index )

    // target-region calls with bcftools
    ch_targets_in = ch_bam.map { meta, bam, bai -> tuple(meta + [ call_type: 'targets' ], bam, bai) }

    BCFTOOLS_MPILEUP_CALL(
        ch_targets_in,
        ch_fasta.combine( ch_fasta_fai.map { m, fai -> fai } ).map { m, fasta, fai -> tuple(m, fasta, fai) }.first(),
        ploidy_file,
        targets_bed
    )

    // Whole-amplicon calls with Clair3, which needs a downloaded model directory
    if ( !params.clair3_model_path ) {
        error "params.clair3_model_path is required for nanopore (path to a downloaded Clair3 PyTorch model directory containing pileup.pt and full_alignment.pt)."
    }
    ch_clair3_model = file(params.clair3_model_path, checkIfExists: false)

    ch_clair3_in = ch_bam.map { meta, bam, bai ->
        tuple(meta + [ call_type: 'amplicons' ], bam, bai, [], ch_clair3_model, 'ont')
    }

    CLAIR3(
        ch_clair3_in,
        ch_fasta,
        ch_fasta_fai
    )

    MASK_CLAIR3_GVCF( CLAIR3.out.gvcf, params.min_genotype_depth )

    emit:
    bam               = ch_bam
    calls             = BCFTOOLS_MPILEUP_CALL.out.vcf.mix( MASK_CLAIR3_GVCF.out.vcf )
    fastp_json        = FASTPLONG.out.json.map { meta, json -> json }
}
