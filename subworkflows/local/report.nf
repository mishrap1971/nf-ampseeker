// builds the HTML report from all executed notebooks plus the static report files (ampseeker logo, intro page, config)

include { JUPYTER_BOOK } from '../../modules/local/jupyter_book'

workflow REPORT {

    take:
    ch_notebooks

    main:
    ch_static_assets = Channel.fromPath("${projectDir}/assets/jupyterbook/*").collect()

    JUPYTER_BOOK( ch_notebooks.collect(), ch_static_assets )

    emit:
    html      = JUPYTER_BOOK.out.html
    home_page = JUPYTER_BOOK.out.home_page
}
