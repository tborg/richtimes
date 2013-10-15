from richtimes import app, db
from richtimes.news.models import PubData
from glob import glob
from os.path import join, basename


def get_issues(filenames):
    """
    Iterates through all of the XML files in the main XML directory (set in
    app.config), building up a row of metadata for each issue of the Richmond
    Times in the richtimes.pub_data table. This process should only be run once
    on a clean database.
    """
    issues = map(get_issue, filenames)
    db.session.commit()
    return issues


def get_issue(fname):
    p = PubData(basename(fname))
    print '{}-{}-{}'.format(p.year, p.month, p.day)
    db.session.add(p)
    return p


def get_sections(issues):
    """
    Iterate through all of the issues, indexing sections by type.
    """
    section_types = {}
    for i in issues:
        print 'sections for {}-{}-{}'.format(i.year, i.month, i.day)
        i.get_sections(section_types)
    db.session.commit()


def get_subsections(issues):
    """
    Iterate through all of the issues, indexing subsections by type.=
    """
    subsection_types = {}
    for i in issues:
        print 'subsections for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.sections.all():
            s.get_subsections(subsection_types)
    db.session.commit()


def get_articles(issues):
    """
    Iterate through all of the issues, indexing articles by type.
    """
    article_types = {}
    for i in issues:
        print 'articles for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.subsections.all():
            s.get_articles(article_types)
    db.session.commit()


def get_pers_names(issues):
    """
    Iterate through all of the issues, indexing persName mentions.
    """
    pers_names = {}
    tags = {}
    for i in issues:
        print 'pers names for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.articles.all():
            s.get_pers_names(pers_names, tags)
    print 'found {} persNames with {} tags'.format(len(pers_names.keys()),
                                                   len(tags.keys()))
    db.session.commit()


def get_place_names(issues):
    """
    Iterate through all of the issues, indexing placeName mentions.
    """
    placeNames = {}
    for i in issues:
        print 'place names for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.articles.all():
            s.get_place_names(placeNames)
    print 'found {} placeNames'.format(len(placeNames.keys()))
    db.session.commit()


def get_org_names(issues):
    """
    Iterate through all of the issues, indexing orgName mentions.
    """
    org_types = {}
    for i in issues:
        print 'org names for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.articles.all():
            s.get_org_names(org_types)
    db.session.commit()


def get_ref_strings(issues):
    """
    Iterate through all of the issues, indexing referencing strings.
    """
    ref_string_types = {}
    for i in issues:
        print 'referencing strings for {}-{}-{}'.format(i.year, i.month, i.day)
        for s in i.articles.all():
            s.get_ref_strings(ref_string_types)
    db.session.commit()


def iterissues(size=50):
    filenames = glob(join(app.root_path, app.config['XML_DIR'], '*.xml'))
    while filenames:
        yield get_issues(filenames[:size])
        filenames = filenames[size:]


def build_pub_data():
    for issues in iterissues():
        get_sections(issues)
        get_subsections(issues)
        get_articles(issues)
        get_pers_names(issues)
        get_place_names(issues)
        get_org_names(issues)
        get_ref_strings(issues)
