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


@news.route('/content', methods=['GET'])
def content():
    data = {}
    for article in models.Article.query.all():
        category_id = article.subsection.type_id
        content_type_id = article.type_id
        issue_id = article.issue_id
        category = data.get(category_id, {})
        content_type = category.get(content_type_id, {})
        issue = content_type.get(issue_id, [])
        issue.append(article.id)
        content_type[issue_id] = issue
        category[content_type_id] = content_type
        data[category_id] = category
    return jsonify(data)


@news.route('/content/articles', methods=['GET'])
def articles():
    ids = filter(bool, request.values.get('ids', '').split(','))
    articles = models.Article.query.filter(models.Article.id.in_(ids)).all()
    return jsonify({'articles': [a.to_json() for a in articles]})
