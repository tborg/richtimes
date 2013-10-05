class Config:
    CONNECTIONS = {}
    SQLALCHEMY_BINDS = {key: "mysql+mysqldb://%(user)s:%(password)s@%(host)s/%(database)s?charset=utf8" % value for key, value in CONNECTIONS.iteritems()}
    SQLALCHEMY_POOL_RECYCLE = 3600
    SQLALCHEMY_ECHO = False
    SQLALCHEMY_COMMIT_ON_TEARDOWN = True
