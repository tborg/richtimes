from richtimes import db


class PubData(db.Model):
    """
    This table holds basic publication data about each issue of the Richmond
    Daily Dispatch in the corpus. The most salient facets are probably year,
    month, and day.

    In addition to the metadata stored in the table, this class provides an
    accessor to an lxml.etree instance of the issue's TEI: `get_etree`. This is
    the preferred method for accessing the XML.
    """
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), unique=True)
    year = db.Column(db.Integer)
    month = db.Column(db.Integer)
    day = db.Column(db.Integer)
    volume = db.Column(db.String(10))
    filename = db.Column(db.String(50), unique=True)

    def __init__(self, filename):
        self.filename = filename
        tree = self.get_etree()
        self._parse(tree)

    def get_etree(self):
        """
        Get an etree instance of the issue.
        :return: An lxml.etree instance of the issue's TEI representation.
        """
        from richtimes.scripts.shell import get_etree
        return get_etree(self.filename)

    def _parse(self, tree):
        """
        Called when a PubData model is initialized; uses xpath to track down
        the metadata we're interested in from the teiHeader.
        :param tree: The lxml.etree instance of this issue.
        """
        bibl = tree.xpath('/TEI.2/teiHeader//biblFull')[0]
        date_string = bibl.xpath('.//date')[0].attrib['value']
        self.year, self.month, self.day = date_string.split('-')
        self.volume = bibl.xpath('.//idno')[0].text
        self.title = bibl.xpath('.//title')[0].text

    def to_json(self):
        """
        Get a jsonifiable representation of this table.
        :return: A dictionary of this instance's attributes.
        """
        return {'id': self.id,
                'title': self.title,
                'year': self.year,
                'month': self.month,
                'day': self.day,
                'volume': self.volume,
                'filename': self.filename}
