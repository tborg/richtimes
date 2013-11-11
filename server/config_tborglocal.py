from config_common import Config as CommonConfig


class Config(CommonConfig):
    CONNECTIONS = {'richtimes': {'host': 'localhost',
                                 'port': '3306',
                                 'user': 'richtimes_test',
                                 'password': 'localghost',
                                 'database': 'richtimes'}}

    SQLALCHEMY_BINDS = {key: "mysql+mysqldb://%(user)s:%(password)s@%(host)s/%(database)s?charset=utf8" % value for key, value in CONNECTIONS.iteritems()}

    APP_ROOT_FROM_MAIN = '../../'

    XML_DIR = APP_ROOT_FROM_MAIN + '/bower_components/richtimes-xml'
    JSON_DIR = APP_ROOT_FROM_MAIN + '/app/json'
