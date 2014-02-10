from os import environ, path


class Config(dict):
    SQLALCHEMY_POOL_RECYCLE = 3600
    SQLALCHEMY_ECHO = False
    SQLALCHEMY_COMMIT_ON_TEARDOWN = True
    CONNECTIONS = {'richtimes': {'host': environ['RICHTIMES_MYSQL_HOST'],
                                 'port': environ['RICHTIMES_MYSQL_PORT'],
                                 'user': environ['RICHTIMES_MYSQL_USER'],
                                 'password': environ['RICHTIMES_MYSQL_PASS'],
                                 'database': 'richtimes'}}

    SQLALCHEMY_BINDS = {key: "mysql+mysqldb://%(user)s:%(password)s@%(host)s/%(database)s?charset=utf8" % value for key, value in CONNECTIONS.iteritems()}

    APP_ROOT_FROM_MAIN = '../../'

    XML_DIR = path.join(APP_ROOT_FROM_MAIN, 'bower_components/richtimes-xml')
    JSON_DIR = path.join(APP_ROOT_FROM_MAIN, 'app/json')
