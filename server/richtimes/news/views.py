from flask import Blueprint, jsonify, request
from richtimes.news import models

news = Blueprint('news', __name__)


def paginate(q, default=25):
    offset = int(request.values.get('offset', 0))
    if offset:
        q = q.offset(offset)
    limit = request.values.get('limit')
    if limit:
        q = q.limit(limit)
    return (q, offset)


@news.route('/dates')
def get_dates():
    issues = models.PubData.query.all()
    dates = {}
    for i in issues:
        months = dates.get(i.year, {})
        days = months.get(i.month, {'days': []})
        days['days'].append(i.day)
        months[i.month] = days
        dates[i.year] = months
    dates = [{'id': k, 'months': v} for k, v in dates.iteritems()]
    return jsonify({'dates': dates})


@news.route('/issues/<id>')
def get_issues(id):
    year, month, day = id.split('-')
    i = models.PubData.query.filter_by(year=year, month=month, day=day).first()
    return jsonify({'issue': i.to_json()})
