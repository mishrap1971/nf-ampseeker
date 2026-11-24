// Exports the target and amplicon SNPs to spreadsheets (snp-dataframe notebook).
// Kept separate from main analysis (in analysis.nf) because the kdr analysis needs its output.

include { PAPERMILL_NOTEBOOK as PAPERMILL_SNP_DATAFRAME } from '../../modules/local/papermill_notebook'
include { inputName } from '../../lib/utils'

workflow SNP_DATAFRAME {

    take:
    ch_annot_targets
    ch_annot_amplicons

    main:
    ch_lib = file("${projectDir}/assets/notebooks/lib")
    def dataset  = params.dataset
    def platform = params.platform

    PAPERMILL_SNP_DATAFRAME(
        ch_annot_targets.first().combine(ch_annot_amplicons.first())
            .map { targets_f, amplicons_f ->
                def files = [ targets_f, amplicons_f ]
                tuple(
                    'snp-dataframe',
                    file("${projectDir}/assets/notebooks/snp-dataframe.ipynb"),
                    files,
                    [
                        "results/vcfs/targets/${dataset}.annot.vcf": inputName(files, targets_f),
                        "results/vcfs/amplicons/${dataset}.annot.vcf": inputName(files, amplicons_f),
                    ],
                    [ dataset: dataset, platform: platform, wkdir: '.' ]
                )
            },
        ch_lib
    )

    emit:
    notebooks    = PAPERMILL_SNP_DATAFRAME.out.notebook.map { n, f -> f }
    targets_xlsx = PAPERMILL_SNP_DATAFRAME.out.extra_xlsx
                       .map { fs -> (fs instanceof List ? fs : [ fs ]).find { it.parent.name == 'targets' } }
}
