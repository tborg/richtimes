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


@news.route('/articles/<date>/<subsection_type>', methods=['GET'])
def articles(date, subsection_type):
    articles = models.Article.query
    arts = articles.filter_by(date=date, subsection_type=subsection_type).all()
    return jsonify({'data': [a.to_json() for a in arts]})
