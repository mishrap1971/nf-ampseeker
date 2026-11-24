// builds the HTML result report from the executed notebooks, a page is listed only if its notebook exists

process JUPYTER_BOOK {
    label 'process_medium'
    // copy, the script edits the staged notebooks and must never touch the original jupyter nbs
    stageInMode 'copy'

    input:
    path notebooks, stageAs: 'pages/notebooks/*'
    path static_assets, stageAs: 'pages/*'

    output:
    path "ampseeker-results/_build/html", emit: html
    path "ampseeker-results/_build/html/index.html", emit: home_page

    script:
    """
    python3 - <<'PYEOF'
import glob, json, os, shutil, yaml

# ag-vampir pages go to their own subfolder
os.makedirs('pages/notebooks/ag-vampir', exist_ok=True)
for name in ('species-id', 'kdr-analysis'):
    src = f'pages/notebooks/{name}.ipynb'
    if os.path.exists(src):
        shutil.move(src, f'pages/notebooks/ag-vampir/{name}.ipynb')

# keep only the table-of-contents of entries whose notebook exists
with open('pages/_toc_skeleton.yml') as f:
    toc = yaml.safe_load(f)

present = {p[len('pages/'):-len('.ipynb')] for p in glob.glob('pages/notebooks/**/*.ipynb', recursive=True)}

for part in toc['parts']:
    part['chapters'] = [c for c in part['chapters'] if c['file'] in present]
toc['parts'] = [p for p in toc['parts'] if p['chapters']]

with open('pages/_toc.yml', 'w') as f:
    yaml.dump(toc, f)

# the notebooks link to result files as ./results/<path>; point those links at <outdir>/<path>,
# which is 3 levels above the built html folder (ampseeker-results/_build/html), plus the page's own depth
def fix_links(obj, prefix):
    if isinstance(obj, str):
        return obj.replace('href=./results/', 'href=' + prefix).replace('href="./results/', 'href="' + prefix)
    if isinstance(obj, list):
        return [fix_links(x, prefix) for x in obj]
    if isinstance(obj, dict):
        return {k: fix_links(v, prefix) for k, v in obj.items()}
    return obj

# hide each notebook's parameter cell in the report, and fix its links
for nb_path in glob.glob('pages/notebooks/**/*.ipynb', recursive=True):
    with open(nb_path) as f:
        nb = json.load(f)
    if len(nb['cells']) > 2:
        nb['cells'][2].setdefault('metadata', {})['tags'] = ['remove-input']
    depth = os.path.relpath(nb_path, 'pages').count(os.sep)
    prefix = '../' * (depth + 3)
    for cell in nb['cells']:
        if 'outputs' in cell:
            cell['outputs'] = fix_links(cell['outputs'], prefix)
    with open(nb_path, 'w') as f:
        json.dump(nb, f)
PYEOF

    jupyter-book build --all pages --path-output ampseeker-results
    """

    stub:
    """
    mkdir -p ampseeker-results/_build/html
    touch ampseeker-results/_build/html/index.html
    """
}
