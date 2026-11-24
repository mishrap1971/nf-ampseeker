// builds or downloads the snpEff database, then annotates the merged VCFs with variant effects

include { SNPEFF_DB_DOWNLOAD } from '../../modules/local/snpeff_db_download'
include { SNPEFF_CUSTOM_DB   } from '../../modules/local/snpeff_custom_db'
include { SNPEFF_ANNOTATE    } from '../../modules/local/snpeff_annotate'
include { paramBoolean       } from '../../lib/utils'

workflow ANNOTATE {

    take:
    ch_merged_vcf
    ch_fasta
    gff3

    main:
    // Build the snpeff database from the reference FASTA + GFF, or download a named one (usually available for well-studied species or model organisms only)
    if ( paramBoolean(params.custom_snpeffdb) ) {
        SNPEFF_CUSTOM_DB( ch_fasta.map { meta, fa -> fa }, gff3 )
        ch_db = SNPEFF_CUSTOM_DB.out.db_dir
    } else {
        SNPEFF_DB_DOWNLOAD( params.reference_snpeffdb )
        ch_db = SNPEFF_DB_DOWNLOAD.out.db_dir
    }

    // The database is reused for every VCF (.first()).
    SNPEFF_ANNOTATE( ch_merged_vcf, ch_db.first() )

    emit:
    vcf  = SNPEFF_ANNOTATE.out.vcf
    html = SNPEFF_ANNOTATE.out.html
    csv  = SNPEFF_ANNOTATE.out.csv
}
