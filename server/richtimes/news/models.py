from richtimes import db


class PubData(db.Model):
    __bind_key__ = 'richtimes'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), unique=True)
    year = db.Column(db.Integer)
    month = db.Column(db.Integer)
    day = db.Column(db.Integer)
    volume = db.Column(db.Float(precision=3), unique=True)
