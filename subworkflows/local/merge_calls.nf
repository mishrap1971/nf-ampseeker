// compresses and indexes per-sample calls, then merges them into one VCF per call type
// bcftools merge can handle only ~1000 files at one, so larger cohorts are merged in a nested manner
// nanopore amplicon calls are gVCFs: merged with -g (see conf/base.config), then reference blocks are dropped

include { HTSLIB_BGZIPTABIX as BGZIP_TABIX_CALLS } from '../../modules/nf-core/htslib/bgziptabix/main'
include { HTSLIB_BGZIPTABIX as BGZIP_TABIX_BATCH } from '../../modules/nf-core/htslib/bgziptabix/main'
include { BCFTOOLS_MERGE                         } from '../../modules/nf-core/bcftools/merge/main'
include { BCFTOOLS_MERGE as BCFTOOLS_MERGE_BATCH } from '../../modules/nf-core/bcftools/merge/main'
include { BCFTOOLS_DROP_NON_REF                  } from '../../modules/local/bcftools_drop_non_ref'

workflow MERGE_CALLS {

    take:
    ch_calls_raw
    ch_fasta_fai     // tuple(meta, fasta, fai), used by the gVCF merge

    main:
    // compress + index the uncompressed calls
    BGZIP_TABIX_CALLS(
        ch_calls_raw.map { meta, vcf -> tuple(meta, vcf, [], []) },
        'compress', true, 'calls.vcf'
    )
    ch_calls_all = BGZIP_TABIX_CALLS.out.output.join( BGZIP_TABIX_CALLS.out.index )

    // group by call type and split into batches of up to 1000 samples
    ch_batches = ch_calls_all
        .map { meta, vcf, tbi -> tuple(meta.call_type, vcf, tbi) }
        .groupTuple()
        .flatMap { call_type, vcfs, tbis ->
            def n = vcfs.size()
            def n_batches = (n + 999).intdiv(1000)
            (0..<n).collate(1000).withIndex().collect { idxs, i ->
                def id = n_batches == 1 ? "${params.dataset}.merged" : "${params.dataset}.${call_type}.batch${i}"
                def meta = [ id: id, call_type: call_type, n_batches: n_batches ]
                tuple(meta, idxs.collect { vcfs[it] }, idxs.collect { tbis[it] })
            }
        }

    // merge each batch
    BCFTOOLS_MERGE_BATCH(
        ch_batches.map { meta, vcfs, tbis -> tuple(meta, vcfs, tbis, []) },
        ch_fasta_fai
    )

    // if there are more than 1000 samples, there will be several batches, which will need a as many rounds of bcftools-merge
    ch_batch_result = BCFTOOLS_MERGE_BATCH.out.vcf.branch { meta, vcf ->
        single: meta.n_batches == 1
        multi:  meta.n_batches > 1
    }

    BGZIP_TABIX_BATCH( ch_batch_result.multi.map { meta, vcf -> tuple(meta, vcf, [], []) }, 'compress', true, [] )

    ch_second_stage_in = BGZIP_TABIX_BATCH.out.output.join( BGZIP_TABIX_BATCH.out.index )
        .map { meta, vcf, tbi -> tuple(meta.call_type, vcf, tbi) }
        .groupTuple()
        .map { call_type, vcfs, tbis -> tuple([ id: "${params.dataset}.merged", call_type: call_type ], vcfs, tbis, []) }

    BCFTOOLS_MERGE( ch_second_stage_in, ch_fasta_fai )

    // final merged VCF per call type, labelled with the dataset name
    ch_merged = ch_batch_result.single
        .mix( BCFTOOLS_MERGE.out.vcf )
        .map { meta, vcf -> tuple([ id: params.dataset, call_type: meta.call_type ], vcf) }
        .branch { meta, vcf ->
            gvcf:  params.platform == 'nanopore' && meta.call_type == 'amplicons'
            plain: true
        }

    BCFTOOLS_DROP_NON_REF( ch_merged.gvcf )

    ch_final = ch_merged.plain.mix( BCFTOOLS_DROP_NON_REF.out.vcf )

    emit:
    merged_vcf = ch_final
}
