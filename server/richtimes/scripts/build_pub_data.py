from richtimes import app, db
from richtimes.news.models import PubData
from glob import glob
from os.path import join, basename


def build_pub_data():
    """
    Iterates through all of the XML files in the main XML directory (set in
    app.config), building up a row of metadata for each issue of the Richmond
    Times in the richtimes.pub_data table. This process should only be run once
    on a clean database.
    """
    print ""
    filenames = glob(join(app.root_path, app.config['XML_DIR'], '*.xml'))
    print 'Building publication data for {} issues.'.format(len(filenames))
    count = 0
    for f in filenames:
        p = PubData(basename(f))
        print '{}-{}-{}'.format(p.year, p.month, p.day)
        db.session.add(p)
        count += 1
    print 'committing {} files'.format(count)
    db.session.commit()
    print 'Finished getting publication data.'
